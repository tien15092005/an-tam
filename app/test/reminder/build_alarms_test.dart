import 'package:app/domain/schedule_expander.dart';
import 'package:app/features/elder/alarm_screen.dart' show doseMinuteOf;
import 'package:app/reminder/alarm_channel.dart';
import 'package:app/reminder/elder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

ElderMed med(int id, String name, List<String> times, {DateTime? createdAt, DateTime? end, int mask = 127}) => ElderMed(
      id: id,
      name: name,
      dosage: '1 viên',
      description: 'viên tròn, màu trắng',
      times: times.map(TimeOfDose.parse).toList(),
      daysMask: mask,
      startDate: DateTime(2026, 11, 1),
      endDate: end,
      createdAt: createdAt ?? DateTime(2026, 11, 1, 9),
    );

void main() {
  final now = DateTime(2026, 11, 9, 7, 45); // Monday morning

  test('doses at the same minute share one alarm and are read out together', () {
    final s = ElderSchedule(callName: 'Bà Lan', version: 3, meds: [
      med(1, 'Amlodipin', ['08:00', '20:00']),
      med(2, 'Metformin', ['08:00']),
    ]);
    final alarms = buildAlarms(s, now, days: 1);
    expect(alarms.map((a) => a.at), [DateTime(2026, 11, 9, 8), DateTime(2026, 11, 9, 20)]);
    expect(alarms.first.speech, contains('Bà Lan ơi'));
    expect(alarms.first.speech, contains('Amlodipin'));
    expect(alarms.first.speech, contains('Metformin'));
    expect(alarms.first.speech, contains('Có 2 loại'));
    expect(alarms[1].speech, isNot(contains('Metformin')));
  });

  test('covers 7 days and skips times already past', () {
    final alarms = buildAlarms(ElderSchedule(callName: '', version: 1, meds: [med(1, 'A', ['07:00', '21:00'])]), now);
    expect(alarms.length, 13); // today's 07:00 is past
    expect(alarms.first.at, DateTime(2026, 11, 9, 21));
    expect(alarms.last.at, DateTime(2026, 11, 15, 21));
  });

  test('a deleted medication leaves no alarm, an ended course stops on its last day', () {
    expect(buildAlarms(const ElderSchedule(callName: '', version: 2, meds: []), now), isEmpty);
    final alarms = buildAlarms(
        ElderSchedule(callName: '', version: 1, meds: [med(1, 'A', ['08:00'], end: DateTime(2026, 11, 10))]), now);
    expect(alarms.map((a) => a.at), [DateTime(2026, 11, 9, 8), DateTime(2026, 11, 10, 8)]);
  });

  test('a medication added today does not ring for times before it was added', () {
    final addedAt = DateTime(2026, 11, 9, 7, 30);
    final alarms = buildAlarms(
        ElderSchedule(callName: '', version: 1, meds: [med(1, 'A', ['07:40', '08:00'], createdAt: addedAt)]),
        DateTime(2026, 11, 9, 7, 35),
        days: 1);
    expect(alarms.map((a) => a.at), [DateTime(2026, 11, 9, 7, 40), DateTime(2026, 11, 9, 8)]);
  });

  test('alarm ids encode the minute, for schedule alarms and their snoozes', () {
    final at = DateTime(2026, 11, 9, 20);
    final id = alarmIdForMinute(at);
    expect(id, greaterThanOrEqualTo(scheduleIdBase));
    expect(doseMinuteOf(id), at);
    expect(doseMinuteOf(id - 50000000), at);
    expect(doseMinuteOf(12345), isNull);
    final s = ElderSchedule(callName: '', version: 1, meds: [med(1, 'A', ['20:00']), med(2, 'B', ['08:00'])]);
    expect(s.medsAt(doseMinuteOf(id)!).map((m) => m.name), ['A']);
  });

  ElderExercise walk({int mask = 127, String time = '06:30', int? minutes = 20}) => ElderExercise(
        id: 9,
        title: 'Đi bộ',
        time: TimeOfDose.parse(time),
        daysMask: mask,
        durationMin: minutes,
        startDate: DateTime(2026, 11, 1),
        createdAt: DateTime(2026, 11, 1, 9),
      );

  test('a Monday-Wednesday-Friday exercise rings on exactly those days, with its own words', () {
    final s = ElderSchedule(callName: 'Bà Lan', version: 1, meds: const [], exercises: [walk(mask: weekdayMask([1, 3, 5]))]);
    final alarms = buildAlarms(s, DateTime(2026, 11, 9, 5), days: 7); // Monday 05:00
    expect(alarms.map((a) => a.at.weekday), [1, 3, 5]);
    expect(alarms.first.speech, contains('đến giờ tập thể dục'));
    expect(alarms.first.speech, contains('Đi bộ, 20 phút'));
    expect(alarms.first.speech, isNot(contains('uống thuốc')));
    expect(alarms.first.title, 'Tập thể dục: Đi bộ');
  });

  test('a medicine and an exercise at the same minute share one alarm, medicine first', () {
    final s = ElderSchedule(
        callName: 'Bà Lan', version: 1, meds: [med(1, 'Amlodipin', ['06:30'])], exercises: [walk()]);
    final alarms = buildAlarms(s, DateTime(2026, 11, 9, 5), days: 1);
    expect(alarms, hasLength(1));
    expect(alarms.single.speech.indexOf('Amlodipin'), lessThan(alarms.single.speech.indexOf('Đi bộ')));
    expect(s.medsAt(alarms.single.at).map((m) => m.name), ['Amlodipin']);
    expect(s.exercisesAt(alarms.single.at).map((e) => e.title), ['Đi bộ']);
  });

  test('an exercise already done today does not ring again', () {
    final day = DateTime(2026, 11, 9);
    final s = ElderSchedule(
        callName: '', version: 1, meds: const [], exercises: [walk(time: '17:00')], exercisesDone: {exerciseKey(9, day)});
    final alarms = buildAlarms(s, DateTime(2026, 11, 9, 8), days: 2);
    expect(alarms.map((a) => a.at), [DateTime(2026, 11, 10, 17)]);
    expect(s.exercisesOn(day).single.done, isTrue);
  });
}
