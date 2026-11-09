import 'dart:convert';
import 'dart:io';

import 'package:app/domain/dose_status.dart';
import 'package:app/domain/schedule_expander.dart';
import 'package:flutter_test/flutter_test.dart';

/// The same files the backend's SharedVectorsTest runs: Dart and Java must agree on every case.
Map<String, dynamic> _load(String name) =>
    jsonDecode(File('../shared/test-vectors/$name').readAsStringSync()) as Map<String, dynamic>;

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
    'T${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

const _names = {
  DoseStatus.upcoming: 'UPCOMING',
  DoseStatus.due: 'DUE',
  DoseStatus.missed: 'MISSED',
  DoseStatus.taken: 'TAKEN',
  DoseStatus.notTaken: 'NOT_TAKEN',
  DoseStatus.skipped: 'SKIPPED',
  DoseStatus.notApplicable: 'NOT_APPLICABLE',
};

void main() {
  group('dose-status.json', () {
    for (final c in (_load('dose-status.json')['cases'] as List).cast<Map<String, dynamic>>()) {
      test(c['name'], () {
        final actual = doseStatusOf(
          due: DateTime.parse(c['due'] as String),
          now: DateTime.parse(c['now'] as String),
          createdAt: DateTime.parse(c['createdAt'] as String),
          logStatus: c['log'] as String?,
        );
        expect(_names[actual], c['expected']);
      });
    }
  });

  group('schedule-expansion.json', () {
    for (final c in (_load('schedule-expansion.json')['cases'] as List).cast<Map<String, dynamic>>()) {
      test(c['name'], () {
        final m = c['medication'] as Map<String, dynamic>;
        final actual = expandSchedule(
          times: (m['times'] as List).cast<String>().map(TimeOfDose.parse).toList(),
          daysMask: weekdayMask((m['daysOfWeek'] as List).cast<int>()),
          startDate: DateTime.parse(m['startDate'] as String),
          endDate: m['endDate'] == null ? null : DateTime.parse(m['endDate'] as String),
          from: DateTime.parse(c['from'] as String),
          to: DateTime.parse(c['to'] as String),
        );
        expect(actual.map(_iso).toList(), c['expected']);
      });
    }
  });
}
