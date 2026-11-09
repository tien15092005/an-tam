import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import 'elder_schedule.dart';
import 'schedule_db.dart';
import 'schedule_sync.dart';

/// Problems the elder can report (plan §9). Names match the backend's Alert.Kind.
enum IssueKind {
  lostMedicine('LOST_MEDICINE'),
  outOfMedicine('OUT_OF_MEDICINE'),
  unsurePill('UNSURE_PILL'),
  unwell('UNWELL'),
  otherIssue('OTHER_ISSUE');

  const IssueKind(this.api);
  final String api;
}

String _two(int n) => n.toString().padLeft(2, '0');

String newEventId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// Doses the phone answered that the server has not received yet (see `doseKey`).
Future<Set<String>> pendingDoseKeys(ScheduleDb db) async {
  final out = <String>{};
  for (final e in await (db.select(db.pendingEvents)..where((e) => e.path.equals('/api/me/dose-reports'))).get()) {
    final b = jsonDecode(e.body) as Map<String, dynamic>;
    final date = DateTime.parse(b['scheduledDate'] as String);
    final hm = (b['scheduledTime'] as String).split(':');
    final at = DateTime(date.year, date.month, date.day, int.parse(hm[0]), int.parse(hm[1]));
    for (final m in (b['medicationIds'] as List).cast<int>()) {
      out.add(doseKey(m, at));
    }
  }
  return out;
}

/// Everything the elder presses is written here first and sent when the server can be reached.
/// The elder never sees a network error: the screen moves on and the queue keeps trying.
class Outbox {
  Outbox(this._ref);
  final Ref _ref;
  Future<void>? _running;
  bool _again = false;

  /// An unanswered "any problem?" question is closed as "no response" after this long (plan: 2 minutes).
  static const questionTimeout = Duration(minutes: 2);

  ScheduleDb get _db => _ref.read(scheduleDbProvider);

  /// Called the moment the elder presses ĐÃ UỐNG RỒI / KHÔNG UỐNG ĐƯỢC: the dose is recorded on the
  /// phone at once. The report waits for the answer to "any problem?" (or the timeout) before sending.
  Future<String> startDoseReport({
    required DateTime minute,
    required List<int> medicationIds,
    required bool taken,
    bool byVoice = false,
  }) async {
    final status = taken ? 'TAKEN' : 'NOT_TAKEN';
    final id = newEventId();
    await _db.transaction(() async {
      for (final m in medicationIds) {
        await _db.recordDose(m, minute, status);
      }
      await _db
          .into(_db.pendingEvents)
          .insert(
            PendingEventsCompanion.insert(
              clientEventId: id,
              path: '/api/me/dose-reports',
              body: jsonEncode({
                'clientEventId': id,
                'scheduledDate': '${minute.year}-${_two(minute.month)}-${_two(minute.day)}',
                'scheduledTime': '${_two(minute.hour)}:${_two(minute.minute)}',
                'medicationIds': medicationIds,
                'status': status,
                'source': byVoice ? 'VOICE' : 'BUTTON',
                'checkResult': 'NO_RESPONSE',
                'issue': null,
                'occurredAt': DateTime.now().toUtc().toIso8601String(),
              }),
              createdAt: DateTime.now(),
            ),
          );
    });
    return id;
  }

  /// The answer to "any problem?": null issue = "Không có gì"; [noResponse] = the question timed out.
  Future<void> finishDoseReport(String id, {IssueKind? issue, bool noResponse = false}) async {
    final row = await (_db.select(_db.pendingEvents)..where((e) => e.clientEventId.equals(id))).getSingleOrNull();
    if (row == null) return;
    final body = jsonDecode(row.body) as Map<String, dynamic>
      ..['checkResult'] = noResponse ? 'NO_RESPONSE' : (issue == null ? 'NONE' : 'ISSUE')
      ..['issue'] = noResponse ? null : issue?.api;
    await (_db.update(_db.pendingEvents)..where((e) => e.id.equals(row.id))).write(
      PendingEventsCompanion(body: Value(jsonEncode(body)), ready: const Value(true)),
    );
    flush();
  }

  /// "TÔI ĐI TẬP ĐÂY": recorded on the phone at once, sent when possible.
  Future<void> reportExercise({required int exerciseId, required DateTime day, bool byVoice = false}) async {
    final id = newEventId();
    final d = DateTime(day.year, day.month, day.day);
    await _db.transaction(() async {
      await _db.recordExercise(exerciseId, d);
      await _db.into(_db.pendingEvents).insert(
            PendingEventsCompanion.insert(
              clientEventId: id,
              path: '/api/me/exercise-reports',
              body: jsonEncode({
                'clientEventId': id,
                'exerciseId': exerciseId,
                'scheduledDate': '${d.year}-${_two(d.month)}-${_two(d.day)}',
                'source': byVoice ? 'VOICE' : 'BUTTON',
              }),
              createdAt: DateTime.now(),
              ready: const Value(true),
            ),
          );
    });
    flush();
  }

  /// "Tôi thấy không khỏe" on the home screen.
  Future<void> raiseAlert(IssueKind kind) async {
    final id = newEventId();
    await _db
        .into(_db.pendingEvents)
        .insert(
          PendingEventsCompanion.insert(
            clientEventId: id,
            path: '/api/me/alerts',
            body: jsonEncode({
              'clientEventId': id,
              'kind': kind.api,
              'occurredAt': DateTime.now().toUtc().toIso8601String(),
            }),
            createdAt: DateTime.now(),
            ready: const Value(true),
          ),
        );
    flush();
  }

  Future<int> pendingCount() async => (await _db.select(_db.pendingEvents).get()).length;

  /// Sends ready events oldest first. Stops at the first network failure and tries again later.
  /// A call while a send is running waits for it, and anything queued meanwhile goes in another round.
  Future<void> flush() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  Future<void> _loop() async {
    do {
      _again = false;
      await _flushOnce();
    } while (_again);
  }

  Future<void> _flushOnce() async {
    // A question left open (app killed, phone switched off) counts as no response.
    final stale = DateTime.now().subtract(questionTimeout + const Duration(seconds: 30));
    final open = await (_db.select(
      _db.pendingEvents,
    )..where((e) => e.ready.equals(false) & e.createdAt.isSmallerThanValue(stale))).get();
    for (final e in open) {
      await finishDoseReport(e.clientEventId, noResponse: true);
    }

    final ready =
        await (_db.select(_db.pendingEvents)
              ..where((e) => e.ready.equals(true))
              ..orderBy([(e) => OrderingTerm.asc(e.id)]))
            .get();
    final dio = _ref.read(dioProvider);
    for (final e in ready) {
      try {
        await dio.post<void>(
          e.path,
          data: e.body,
          options: Options(contentType: Headers.jsonContentType),
        );
        await (_db.delete(_db.pendingEvents)..where((x) => x.id.equals(e.id))).go();
      } on DioException catch (err) {
        final code = err.response?.statusCode;
        await (_db.update(
          _db.pendingEvents,
        )..where((x) => x.id.equals(e.id))).write(PendingEventsCompanion(attempts: Value(e.attempts + 1)));
        // A request the server rejects as invalid will never succeed; drop it rather than block the queue.
        if (code != null && code >= 400 && code < 500 && code != 401 && code != 408 && code != 429) {
          debugPrint('outbox: dropping rejected event ${e.clientEventId} ($code)');
          await (_db.delete(_db.pendingEvents)..where((x) => x.id.equals(e.id))).go();
          continue;
        }
        break; // Offline or server down: keep the order, try later.
      }
    }
  }
}

final outboxProvider = Provider<Outbox>(Outbox.new);
