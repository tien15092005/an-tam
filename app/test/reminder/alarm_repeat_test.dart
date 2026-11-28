import 'package:app/core/theme/tokens.dart';
import 'package:app/domain/dose_status.dart';
import 'package:app/domain/schedule_expander.dart';
import 'package:app/features/caregiver/schedule_tab.dart' show sessionOf;
import 'package:app/features/elder/alarm_screen.dart' show doseMinuteOf;
import 'package:app/reminder/alarm_channel.dart';
import 'package:app/reminder/elder_schedule.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

ElderMed med(int id, String name, List<String> times) => ElderMed(
      id: id,
      name: name,
      description: '',
      times: times.map(TimeOfDose.parse).toList(),
      daysMask: 127,
      startDate: DateTime(2026, 11, 1),
      createdAt: DateTime(2026, 11, 1, 9),
    );

void main() {
  final at1130 = DateTime(2026, 11, 9, 11, 30);
  final s = ElderSchedule(callName: 'Bà Lan', version: 1, meds: [med(1, 'Metformin', ['07:30', '11:30']), med(2, 'Losartan', ['11:30'])]);

  test('caregivers are told 30 minutes after the dose time, after the third ring', () {
    expect(doseGrace, const Duration(minutes: 30));
    expect(maxAlarmAttempts, 3);
    expect(doseStatusOf(due: at1130, now: at1130.add(const Duration(minutes: 30)), createdAt: DateTime(2026, 11, 1)),
        DoseStatus.due);
    expect(doseStatusOf(due: at1130, now: at1130.add(const Duration(minutes: 31)), createdAt: DateTime(2026, 11, 1)),
        DoseStatus.missed);
  });

  test('a dose whose alarm went quiet is offered on the home screen until answered', () {
    final now = DateTime(2026, 11, 9, 11, 45);
    expect(unansweredDoses(s, now).map((d) => (d.at, d.med.name)), [
      (DateTime(2026, 11, 9, 7, 30), 'Metformin'),
      (at1130, 'Metformin'),
      (at1130, 'Losartan'),
    ]);
    // Not while it is still ringing (first two minutes).
    expect(unansweredDoses(s, DateTime(2026, 11, 9, 11, 31)).map((d) => d.at), [DateTime(2026, 11, 9, 7, 30)]);
    final answered = s.copyWith(logs: {
      doseKey(1, DateTime(2026, 11, 9, 7, 30)): 'TAKEN',
      doseKey(1, at1130): 'TAKEN',
      doseKey(2, at1130): 'NOT_TAKEN',
    });
    expect(unansweredDoses(answered, now), isEmpty);
  });

  test('re-rings are dropped only for times where every medicine has an answer', () {
    final now = DateTime(2026, 11, 9, 11, 45);
    final half = s.copyWith(logs: {doseKey(1, at1130): 'TAKEN'});
    expect(answeredAlarmIds(half, now), isEmpty);
    final all = s.copyWith(logs: {doseKey(1, at1130): 'TAKEN', doseKey(2, at1130): 'TAKEN'});
    expect(answeredAlarmIds(all, now), [alarmIdForMinute(at1130)]);
  });

  test('a repeat ring decodes to the same dose minute as the alarm it repeats', () {
    final id = alarmIdForMinute(at1130);
    expect(doseMinuteOf(id - 50000000), at1130);
  });

  test('medicine times are grouped the way families say them', () {
    expect(['06:00', '10:59', '11:30', '13:59', '15:00', '18:00', '21:30'].map(sessionOf),
        ['Sáng', 'Sáng', 'Trưa', 'Trưa', 'Chiều', 'Tối', 'Tối']);
  });

  test('text colours stay readable in light and dark', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
    }

    for (final p in [Palette.light, Palette.dark]) {
      for (final bg in [p.background, p.surface]) {
        expect(contrast(p.ink, bg), greaterThanOrEqualTo(7));
        for (final c in [p.muted, p.primary, p.ok, p.warn, p.danger]) {
          expect(contrast(c, bg), greaterThanOrEqualTo(4.5));
        }
      }
      for (final accent in [p.primary, p.ok, p.danger]) {
        expect(contrast(p.onAccent, accent), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test('a phone whose clock zone differs from the profile is flagged', () {
    final now = DateTime.now();
    final same = ElderSchedule(callName: '', version: 1, meds: const [], profileUtcOffsetMinutes: now.timeZoneOffset.inMinutes);
    final other = ElderSchedule(callName: '', version: 1, meds: const [], profileUtcOffsetMinutes: now.timeZoneOffset.inMinutes + 420);
    const unknown = ElderSchedule(callName: '', version: 1, meds: []);
    expect(same.clockZoneDiffers(now), isFalse);
    expect(other.clockZoneDiffers(now), isTrue);
    expect(unknown.clockZoneDiffers(now), isFalse); // not synced with a new server yet: no false alarm
    expect(other.copyWith(offline: true).clockZoneDiffers(now), isTrue);
  });

  test('a low alarm volume makes the phone not ready', () {
    final quiet = AlarmReadiness.fromMap(const {
      'notifications': true, 'exactAlarms': true, 'fullScreen': true, 'batteryUnrestricted': true,
      'vietnameseVoice': true, 'alarmVolume': false,
    });
    expect(quiet.alarmsReady, isFalse);
    final oldBuild = AlarmReadiness.fromMap(const {
      'notifications': true, 'exactAlarms': true, 'fullScreen': true, 'batteryUnrestricted': true, 'vietnameseVoice': true,
    });
    expect(oldBuild.alarmsReady, isTrue);
  });
}
