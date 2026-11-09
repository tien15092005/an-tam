import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators, ComparableExpr, Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/network/api_client.dart';
import '../domain/schedule_expander.dart';
import '../features/medications/medications_api.dart';
import 'alarm_channel.dart';
import 'elder_schedule.dart';
import 'outbox.dart';
import 'schedule_db.dart';

final scheduleDbProvider = Provider<ScheduleDb>((ref) {
  final db = ScheduleDb();
  ref.onDispose(db.close);
  return db;
});

/// The elder's schedule: shown from the saved copy at once, then refreshed from the server.
/// Every state change re-arms the phone's alarms for the next 7 days.
class ElderScheduleNotifier extends AsyncNotifier<ElderSchedule> {
  ScheduleDb get _db => ref.read(scheduleDbProvider);

  @override
  Future<ElderSchedule> build() async {
    final cached = await _loadCached();
    await _arm(cached);
    // Then try the network without blocking the first frame.
    Future.microtask(refresh);
    return cached;
  }

  /// Downloads the schedule and photos; on failure keeps the saved copy (marked offline) and still
  /// re-arms from it, which rolls the 7-day alarm window forward even with no network.
  Future<void> refresh() async {
    // Reports waiting from offline time go first, so the server's recent doses include them.
    await ref.read(outboxProvider).flush();
    try {
      final fresh = await _download();
      state = AsyncData(fresh);
      await _arm(fresh);
    } catch (e) {
      debugPrint('schedule sync failed: $e');
      final cached = state.value ?? await _loadCached();
      // Only "could not reach the server" is offline; a refusal (e.g. not an elder's session) is not.
      final offline = e is! DioException || e.response == null;
      state = AsyncData(offline ? cached.copyWith(offline: true) : cached);
      await _arm(cached);
    }
  }

  /// After the elder answers an alarm: show the answer at once and stop ringing for those doses.
  Future<void> reloadLocal() async {
    final current = state.value;
    final logs = await _loadLogs();
    final next = current == null ? await _loadCached() : current.copyWith(logs: logs);
    state = AsyncData(next);
    await _arm(next);
  }

  /// On sign-out: forget the schedule and silence every future reminder.
  Future<void> clear() async {
    await _db.replaceAll(const [], const []);
    await _db.delete(_db.localDoseLogs).go();
    await _db.delete(_db.localExerciseLogs).go();
    await _db.delete(_db.pendingEvents).go();
    await _db.delete(_db.syncMeta).go(); // version, name, last sync time, saved contacts
    final dir = await _imagesDir();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await _arm(ElderSchedule.empty);
    state = const AsyncData(ElderSchedule.empty);
  }

  Future<void> _arm(ElderSchedule s) async {
    try {
      await AlarmChannel.replaceSchedule(buildAlarms(s, DateTime.now()));
    } on MissingPluginException {
      // Widget tests and non-Android platforms have no native alarm engine.
    } catch (e) {
      debugPrint('arming alarms failed: $e');
    }
  }

  static Future<Directory> _imagesDir() async =>
      Directory(p.join((await getApplicationSupportDirectory()).path, 'med_images'));

  Future<ElderSchedule> _download() async {
    final dio = ref.read(dioProvider);
    final json = (await dio.get<Map<String, dynamic>>('/api/me/schedule')).data!;
    final meds = (json['medications'] as List).map((m) => Medication.fromJson(m as Map<String, dynamic>)).toList();

    // Photos are immutable per id: download only new ones, then drop files no longer used.
    final dir = await _imagesDir();
    dir.createSync(recursive: true);
    final wanted = <String>{};
    final imageRows = <CachedImagesCompanion>[];
    for (final m in meds) {
      for (final img in m.images) {
        final file = File(p.join(dir.path, '${img.id}.jpg'));
        wanted.add(file.path);
        if (!file.existsSync()) {
          final bytes = await dio.get<List<int>>(img.url, options: Options(responseType: ResponseType.bytes));
          final tmp = File('${file.path}.part');
          await tmp.writeAsBytes(bytes.data!, flush: true);
          await tmp.rename(file.path);
        }
        imageRows.add(CachedImagesCompanion.insert(
            id: Value(img.id), medicationId: m.id, kind: img.kind.name, path: file.path, sha256: img.sha256));
      }
    }

    final medRows = [
      for (final m in meds)
        CachedMedicationsCompanion.insert(
          id: Value(m.id),
          seriesId: m.seriesId,
          name: m.name,
          strength: Value(m.strength),
          dosage: Value(m.dosage),
          description: m.description,
          note: Value(m.note),
          times: m.times.join(','),
          daysMask: weekdayMask(m.daysOfWeek),
          startDate: m.startDate,
          endDate: Value(m.endDate),
          createdAt: m.createdAt,
        ),
    ];
    final exerciseRows = [
      for (final e in (json['exercises'] as List? ?? const []).cast<Map<String, dynamic>>())
        CachedExercisesCompanion.insert(
          id: Value(e['id'] as int),
          title: e['title'] as String,
          time: e['time'] as String,
          daysMask: weekdayMask(((e['daysOfWeek'] as List?) ?? const []).cast<int>()),
          durationMin: Value(e['durationMin'] as int?),
          note: Value(e['note'] as String?),
          startDate: DateTime.parse(e['startDate'] as String),
          endDate: Value(e['endDate'] == null ? null : DateTime.parse(e['endDate'] as String)),
          createdAt: DateTime.parse(e['createdAt'] as String).toLocal(),
        ),
    ];
    await _db.replaceAll(medRows, imageRows, exerciseRows);
    for (final x in (json['recentExercises'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final d = DateTime.parse(x['scheduledDate'] as String);
      await _db.recordExercise(x['exerciseId'] as int, DateTime(d.year, d.month, d.day));
    }
    // The server's answers (e.g. from before a reinstall, or a caregiver's mark) join the phone's own;
    // the server wins.
    final serverKeys = <String>{};
    for (final d in (json['recentDoses'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final date = DateTime.parse(d['scheduledDate'] as String);
      final t = TimeOfDose.parse(d['scheduledTime'] as String);
      final at = DateTime(date.year, date.month, date.day, t.hour, t.minute);
      serverKeys.add(doseKey(d['medicationId'] as int, at));
      await _db.into(_db.localDoseLogs).insertOnConflictUpdate(
          LocalDoseLogsCompanion.insert(medicationId: d['medicationId'] as int, scheduledAt: at, status: d['status'] as String));
    }
    // A caregiver undid a mark: the server no longer has it. Answers still waiting in the outbox stay.
    final pending = await pendingDoseKeys(_db);
    final now = DateTime.now();
    final since = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    for (final l in await (_db.select(_db.localDoseLogs)..where((l) => l.scheduledAt.isBiggerOrEqualValue(since))).get()) {
      final k = doseKey(l.medicationId, l.scheduledAt);
      if (!serverKeys.contains(k) && !pending.contains(k)) {
        await (_db.delete(_db.localDoseLogs)
              ..where((x) => x.medicationId.equals(l.medicationId) & x.scheduledAt.equals(l.scheduledAt)))
            .go();
      }
    }
    await (_db.delete(_db.localDoseLogs)
          ..where((l) => l.scheduledAt.isSmallerThanValue(DateTime.now().subtract(const Duration(days: 8)))))
        .go();
    await _db.setMeta('callName', json['callName'] as String? ?? '');
    await _db.setMeta('version', '${json['scheduleVersion']}');
    await _db.setMeta('lastSynced', DateTime.now().toIso8601String());
    // Saved now so "Gọi cho con" works later without network.
    try {
      await fetchContacts(ref, json['groupId'] as int);
    } catch (e) {
      debugPrint('saving contacts failed: $e');
    }
    for (final f in dir.listSync().whereType<File>()) {
      if (!wanted.contains(f.path)) f.deleteSync();
    }
    return _loadCached();
  }

  Future<Map<String, String>> _loadLogs() async => {
        for (final l in await _db.select(_db.localDoseLogs).get()) doseKey(l.medicationId, l.scheduledAt): l.status,
      };

  Future<ElderSchedule> _loadCached() async {
    final logs = await _loadLogs();
    final meds = await _db.select(_db.cachedMedications).get();
    final images = await _db.select(_db.cachedImages).get();
    final exercises = await _db.select(_db.cachedExercises).get();
    final done = await _db.select(_db.localExerciseLogs).get();
    final last = await _db.meta('lastSynced');
    return ElderSchedule(
      callName: await _db.meta('callName') ?? '',
      version: int.tryParse(await _db.meta('version') ?? '') ?? -1,
      lastSynced: last == null ? null : DateTime.parse(last),
      logs: logs,
      exercisesDone: {for (final d in done) exerciseKey(d.exerciseId, d.day)},
      exercises: [
        for (final e in exercises)
          ElderExercise(
            id: e.id,
            title: e.title,
            time: TimeOfDose.parse(e.time),
            daysMask: e.daysMask,
            durationMin: e.durationMin,
            note: e.note,
            startDate: e.startDate,
            endDate: e.endDate,
            createdAt: e.createdAt,
          ),
      ],
      meds: [
        for (final m in meds)
          ElderMed(
            id: m.id,
            name: m.name,
            strength: m.strength,
            dosage: m.dosage,
            description: m.description,
            note: m.note,
            times: m.times.split(',').where((t) => t.isNotEmpty).map(TimeOfDose.parse).toList(),
            daysMask: m.daysMask,
            startDate: m.startDate,
            endDate: m.endDate,
            createdAt: m.createdAt,
            photos: [
              ...images.where((i) => i.medicationId == m.id && i.kind == 'pill').map((i) => i.path),
              ...images.where((i) => i.medicationId == m.id && i.kind != 'pill').map((i) => i.path),
            ],
          ),
      ],
    );
  }
}

final elderScheduleProvider = AsyncNotifierProvider<ElderScheduleNotifier, ElderSchedule>(ElderScheduleNotifier.new);

/// A caregiver the elder can call. Saved on the phone, so "Gọi cho con" works offline.
class Contact {
  const Contact(this.name, this.phone, {this.owner = false});
  final String name;
  final String? phone;
  final bool owner;

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'owner': owner};
  factory Contact.fromJson(Map<String, dynamic> j) =>
      Contact(j['name'] as String, j['phone'] as String?, owner: j['owner'] == true);
}

/// Downloads the family's phone numbers and keeps them on the phone (called on every schedule sync).
Future<List<Contact>> fetchContacts(Ref ref, int groupId) async {
  final detail = (await ref.read(dioProvider).get<Map<String, dynamic>>('/api/groups/$groupId')).data!;
  final contacts = [
    for (final m in (detail['members'] as List).cast<Map<String, dynamic>>())
      if (m['role'] != 'ELDER') Contact(m['displayName'] as String, m['phone'] as String?, owner: m['role'] == 'OWNER'),
  ]..sort((a, b) => (b.owner ? 1 : 0) - (a.owner ? 1 : 0));
  await ref.read(scheduleDbProvider).setMeta('contacts', jsonEncode(contacts.map((c) => c.toJson()).toList()));
  return contacts;
}

final elderContactsProvider = FutureProvider.autoDispose.family<List<Contact>, int>((ref, groupId) async {
  final db = ref.read(scheduleDbProvider);
  try {
    return await fetchContacts(ref, groupId);
  } catch (_) {
    final saved = await db.meta('contacts');
    if (saved == null) rethrow;
    return (jsonDecode(saved) as List).map((c) => Contact.fromJson(c as Map<String, dynamic>)).toList();
  }
});
