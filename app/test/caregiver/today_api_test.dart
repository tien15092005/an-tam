import 'package:app/features/caregiver/today_api.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final json = {
    'date': '2026-11-09',
    'elderUserId': 2,
    'callName': 'Bà Lan',
    'phone': '0900000000',
    'slots': [
      {
        'scheduledTime': '08:00', 'medicationId': 1, 'name': 'Amlodipin', 'status': 'TAKEN', 'doseLogId': 5,
        'source': 'CAREGIVER', 'loggedAt': '2026-11-09T02:10:00Z', 'loggedByName': 'Anh Nam', 'canMark': false, 'canUndo': true,
      },
      {'scheduledTime': '08:00', 'medicationId': 2, 'name': 'Metformin', 'status': 'MISSED', 'canMark': true, 'canUndo': false},
      {
        'scheduledTime': '20:00', 'medicationId': 1, 'name': 'Amlodipin', 'status': 'NOT_TAKEN', 'source': 'BUTTON',
        'checkResult': 'NO_RESPONSE', 'loggedAt': '2026-11-09T13:01:00Z', 'canMark': false, 'canUndo': false,
      },
    ],
    'counts': {'total': 3, 'taken': 1, 'notTaken': 1, 'missed': 1, 'due': 0, 'upcoming': 0},
    'missedLast7Days': 4,
    'openAlerts': 1,
  };

  test('the day view groups doses by alarm time and says who answered', () {
    final v = DayView.fromJson(json);
    expect(v.byTime.keys, ['08:00', '20:00']);
    expect(v.byTime['08:00']!.map((s) => s.name), ['Amlodipin', 'Metformin']);
    expect(v.slots.first.answeredBy, startsWith('Anh Nam đánh dấu giúp lúc'));
    expect(v.slots[1].answeredBy, isNull);
    expect(v.slots[2].checkText, contains('Không trả lời'));
    expect(v.counts['missed'], 1);
    expect(v.missedLast7Days, 4);
  });

  test('every status has an icon and words, not only a colour', () {
    for (final s in ['TAKEN', 'NOT_TAKEN', 'SKIPPED', 'MISSED', 'DUE', 'UPCOMING']) {
      final (_, label, _, _) = statusStyle(s);
      expect(label, isNotEmpty);
    }
    // "Missed" is worded as not confirmed: the phone may have been off (plan §9).
    expect(statusStyle('MISSED').$2, 'Chưa xác nhận');
  });

  test('dates are sent as yyyy-mm-dd', () => expect(ymd(DateTime(2026, 1, 5)), '2026-01-05'));

  CalendarDay day({int total = 0, int taken = 0, int notTaken = 0, int missed = 0, int due = 0, int upcoming = 0,
          int ex = 0, int exDone = 0}) =>
      CalendarDay(DateTime(2026, 11, 9), total, taken, notTaken, missed, due, upcoming, ex, exDone, 0);

  test('the calendar dot shows the worst thing of the day, with words for TalkBack', () {
    expect(day().dot, isNull);
    expect(day(total: 3, taken: 3).dot!.$1, AppColors.ok);
    expect(day(total: 3, taken: 2, notTaken: 1).dot!.$1, AppColors.warn);
    expect(day(total: 3, taken: 1, notTaken: 1, missed: 1).dot!.$1, AppColors.danger);
    expect(day(total: 3, taken: 1, upcoming: 2).dot!.$1, AppColors.navy);
    expect(day(total: 2, taken: 2, ex: 1, exDone: 1).semantics, 'Ngày 9 tháng 11: đã uống đủ 2 lần, tập 1 trên 1 buổi');
    expect(day(total: 2, missed: 2).semantics, contains('2 lần chưa xác nhận'));
  });
}
