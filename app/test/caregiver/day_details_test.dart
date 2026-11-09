import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/caregiver/today_api.dart';
import 'package:app/features/caregiver/today_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Regression: the theme gives buttons a full-width minimum; inside a Row that froze the "Hôm nay" tab.
  testWidgets('the day timeline lays out with mark, undo and call buttons', (tester) async {
    final view = DayView.fromJson({
      'date': '2026-11-09',
      'callName': 'Bà Lan',
      'phone': '0900000000',
      'slots': [
        {'scheduledTime': '08:00', 'medicationId': 1, 'name': 'Amlodipin', 'dosage': '1 viên', 'status': 'MISSED', 'canMark': true, 'canUndo': false},
        {'scheduledTime': '08:00', 'medicationId': 2, 'name': 'Metformin', 'status': 'MISSED', 'canMark': true, 'canUndo': false},
        {
          'scheduledTime': '20:00', 'medicationId': 1, 'name': 'Amlodipin', 'status': 'TAKEN', 'doseLogId': 3, 'source': 'CAREGIVER',
          'loggedAt': '2026-11-09T13:00:00Z', 'loggedByName': 'Anh Nam', 'canMark': false, 'canUndo': true,
        },
      ],
      'counts': {'total': 3, 'taken': 1, 'notTaken': 0, 'missed': 2, 'due': 0, 'upcoming': 0},
      'missedLast7Days': 2,
      'openAlerts': 0,
      'exercises': [
        {'title': 'Đi bộ', 'time': '17:00', 'durationMin': 20, 'status': 'UPCOMING'},
      ],
    });
    var marked = <String>[];
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.build(UiDensity.caregiver),
        home: Scaffold(
          body: ListView(children: [
            DayDetails(view: view, onMark: (t, s) => marked = [t, ...s.map((x) => x.name)], onUndo: (_) {}),
          ]),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Đánh dấu'), findsNWidgets(2));
    expect(find.text('Hoàn tác'), findsOneWidget);
    expect(find.text('Gọi'), findsOneWidget);
    expect(find.text('Đánh dấu cả giờ này'), findsOneWidget);
    await tester.tap(find.text('Đánh dấu cả giờ này'));
    expect(marked, ['08:00', 'Amlodipin', 'Metformin']);
  });
}
