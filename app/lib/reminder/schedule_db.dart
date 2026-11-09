import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'schedule_db.g.dart';

/// The elder's medications as last downloaded. Alarms and the home screen read from here,
/// so both keep working with no network.
class CachedMedications extends Table {
  IntColumn get id => integer()();
  TextColumn get seriesId => text()();
  TextColumn get name => text()();
  TextColumn get strength => text().nullable()();
  TextColumn get dosage => text().nullable()();
  TextColumn get description => text()();
  TextColumn get note => text().nullable()();

  /// "07:30,20:00"
  TextColumn get times => text()();
  IntColumn get daysMask => integer()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Photos saved as files in the app's private folder; this table maps them to medications.
class CachedImages extends Table {
  IntColumn get id => integer()();
  IntColumn get medicationId => integer()();
  TextColumn get kind => text()();
  TextColumn get path => text()();
  TextColumn get sha256 => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Reports and alerts waiting to reach the server. Kept until the server answers, so nothing the
/// elder pressed is lost offline; the server ignores repeats of the same clientEventId.
class PendingEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientEventId => text().unique()();

  /// API path, e.g. /api/me/dose-reports
  TextColumn get path => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// False while the "any problem?" question is still open; only ready events are sent.
  BoolColumn get ready => boolean().withDefault(const Constant(false))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
}

/// What the elder answered for each dose, so the home screen shows "Đã uống" at once, even offline.
class LocalDoseLogs extends Table {
  IntColumn get medicationId => integer()();

  /// The scheduled local minute.
  DateTimeColumn get scheduledAt => dateTime()();

  /// TAKEN | NOT_TAKEN | SKIPPED
  TextColumn get status => text()();

  @override
  Set<Column> get primaryKey => {medicationId, scheduledAt};
}

@DriftDatabase(tables: [CachedMedications, CachedImages, SyncMeta, PendingEvents, LocalDoseLogs])
class ScheduleDb extends _$ScheduleDb {
  ScheduleDb([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'antam_schedule'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(pendingEvents);
            await m.createTable(localDoseLogs);
          }
        },
      );

  /// First answer for a dose wins, as on the server.
  Future<void> recordDose(int medicationId, DateTime at, String status) => into(localDoseLogs)
      .insert(LocalDoseLogsCompanion.insert(medicationId: medicationId, scheduledAt: at, status: status),
          mode: InsertMode.insertOrIgnore);

  Future<String?> meta(String key) async =>
      (await (select(syncMeta)..where((m) => m.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setMeta(String key, String value) =>
      into(syncMeta).insertOnConflictUpdate(SyncMetaCompanion.insert(key: key, value: value));

  /// Replaces the whole cache in one transaction, so a crash mid-sync never leaves half a schedule.
  Future<void> replaceAll(List<CachedMedicationsCompanion> meds, List<CachedImagesCompanion> images) =>
      transaction(() async {
        await delete(cachedMedications).go();
        await delete(cachedImages).go();
        await batch((b) {
          b.insertAll(cachedMedications, meds);
          b.insertAll(cachedImages, images);
        });
      });
}
