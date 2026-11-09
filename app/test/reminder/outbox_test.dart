import 'dart:convert';

import 'package:app/core/network/api_client.dart';
import 'package:app/reminder/elder_schedule.dart';
import 'package:app/reminder/outbox.dart';
import 'package:app/reminder/schedule_db.dart';
import 'package:app/reminder/schedule_sync.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake server: offline until [online] is set, then records every request body.
class FakeServer implements HttpClientAdapter {
  bool online = false;
  int status = 200;
  final List<Map<String, dynamic>> received = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (!online) {
      throw DioException.connectionError(requestOptions: options, reason: 'offline');
    }
    final bytes = await requestStream!.expand((b) => b).toList();
    received.add({'path': options.path, ...jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>});
    return ResponseBody.fromString('{}', status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late ScheduleDb db;
  late FakeServer server;
  late ProviderContainer container;
  late Outbox outbox;

  setUp(() {
    db = ScheduleDb(NativeDatabase.memory());
    server = FakeServer();
    container = ProviderContainer(overrides: [
      scheduleDbProvider.overrideWithValue(db),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = server),
    ]);
    outbox = container.read(outboxProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> pending() async => (await db.select(db.pendingEvents).get()).length;

  test('a confirmed dose is recorded on the phone at once and waits for the answer before sending', () async {
    server.online = true;
    final id = await outbox.startDoseReport(minute: DateTime(2026, 11, 9, 8), medicationIds: [1, 2], taken: true);
    final logs = await db.select(db.localDoseLogs).get();
    expect(logs.map((l) => l.status), ['TAKEN', 'TAKEN']);
    await outbox.flush();
    expect(server.received, isEmpty, reason: 'question still open');

    await outbox.finishDoseReport(id, issue: IssueKind.lostMedicine);
    await outbox.flush();
    expect(server.received, hasLength(1));
    final sent = server.received.single;
    expect(sent['path'], '/api/me/dose-reports');
    expect(sent['clientEventId'], id);
    expect(sent['scheduledDate'], '2026-11-09');
    expect(sent['scheduledTime'], '08:00');
    expect(sent['medicationIds'], [1, 2]);
    expect(sent['status'], 'TAKEN');
    expect(sent['checkResult'], 'ISSUE');
    expect(sent['issue'], 'LOST_MEDICINE');
    expect(await pending(), 0);
  });

  test('"không uống được" is sent as NOT_TAKEN, never as taken', () async {
    server.online = true;
    final id = await outbox.startDoseReport(minute: DateTime(2026, 11, 9, 20), medicationIds: [3], taken: false);
    expect((await db.select(db.localDoseLogs).getSingle()).status, 'NOT_TAKEN');
    await outbox.finishDoseReport(id, issue: IssueKind.outOfMedicine);
    await outbox.flush();
    expect(server.received.single['status'], 'NOT_TAKEN');
  });

  test('offline: kept in order and sent once the network is back, with the same id', () async {
    final a = await outbox.startDoseReport(minute: DateTime(2026, 11, 9, 8), medicationIds: [1], taken: true);
    await outbox.finishDoseReport(a);
    await outbox.raiseAlert(IssueKind.unwell);
    await outbox.flush();
    await outbox.flush();
    expect(await pending(), 2);
    expect(server.received, isEmpty);

    server.online = true;
    await outbox.flush();
    expect(server.received.map((r) => r['path']), ['/api/me/dose-reports', '/api/me/alerts']);
    expect(server.received.first['clientEventId'], a);
    expect(server.received.first['checkResult'], 'NONE');
    expect(server.received.last['kind'], 'UNWELL');
    expect(await pending(), 0);
    await outbox.flush();
    expect(server.received, hasLength(2), reason: 'nothing sent twice once acknowledged');
  });

  test('a question left open (app killed) is sent as NO_RESPONSE later', () async {
    server.online = true;
    await outbox.startDoseReport(minute: DateTime(2026, 11, 9, 8), medicationIds: [1], taken: true);
    // Pretend it was answered long ago.
    await db.update(db.pendingEvents).write(PendingEventsCompanion(createdAt: Value(DateTime.now().subtract(const Duration(minutes: 5)))));
    await outbox.flush();
    expect(server.received.single['checkResult'], 'NO_RESPONSE');
    expect(server.received.single['status'], 'TAKEN', reason: 'no answer keeps the confirmed dose');
  });

  test('a report the server rejects as invalid is dropped instead of blocking the queue', () async {
    server
      ..online = true
      ..status = 400;
    await outbox.raiseAlert(IssueKind.unwell);
    await outbox.flush();
    expect(await pending(), 0);
  });

  test('the first answer for a dose wins on the phone too', () async {
    await outbox.startDoseReport(minute: DateTime(2026, 11, 9, 8), medicationIds: [1], taken: true);
    await outbox.startDoseReport(minute: DateTime(2026, 11, 9, 8), medicationIds: [1], taken: false);
    expect((await db.select(db.localDoseLogs).getSingle()).status, 'TAKEN');
  });

  test('answers still waiting to be sent are known, so a sync never drops them', () async {
    final at = DateTime(2026, 11, 9, 8);
    await outbox.startDoseReport(minute: at, medicationIds: [1, 2], taken: true);
    expect(await pendingDoseKeys(db), {doseKey(1, at), doseKey(2, at)});
    server.online = true;
    await outbox.finishDoseReport((await db.select(db.pendingEvents).getSingle()).clientEventId);
    await outbox.flush();
    expect(await pendingDoseKeys(db), isEmpty);
  });
}
