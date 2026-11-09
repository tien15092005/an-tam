import 'package:app/domain/voice_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('confirming a dose by voice', () {
    for (final s in ['Đã uống', 'uống rồi', 'Bà uống rồi con ạ', 'xong rồi', 'da uong roi', 'Uống xong rồi!']) {
      test('"$s" counts as taken', () => expect(classifyConfirm(s), ConfirmIntent.taken));
    }
    // DoD: "chưa uống" must never count as taken.
    for (final s in ['chưa uống', 'Chưa uống đâu', 'uống chưa nhỉ', 'không, chưa uống', 'quên uống rồi', 'chua uong roi',
      'ko uống']) {
      test('"$s" is NOT taken', () => expect(classifyConfirm(s), isNot(ConfirmIntent.taken)));
    }
    for (final s in ['không uống được', 'Bà không uống được']) {
      test('"$s" is not taken', () => expect(classifyConfirm(s), ConfirmIntent.notTaken));
    }
    for (final s in ['lát nữa', 'chờ chút', 'đợi chút nhé', 'nhắc lại sau']) {
      test('"$s" snoozes', () => expect(classifyConfirm(s), ConfirmIntent.snooze));
    }
    for (final s in ['', 'alo', 'trời hôm nay đẹp', 'uống']) {
      test('"$s" is unclear, keep reminding', () => expect(classifyConfirm(s), ConfirmIntent.unknown));
    }
  });

  group('answering "any problem?" by voice', () {
    final cases = {
      'không có gì': IssueIntent.none,
      'Không sao đâu con': IssueIntent.none,
      'mất thuốc rồi': IssueIntent.lost,
      'hết thuốc': IssueIntent.outOf,
      'thấy mệt quá': IssueIntent.unwell,
      'bà thấy không khỏe': IssueIntent.unwell,
      'thuốc trông khác': IssueIntent.unsure,
      'vấn đề khác': IssueIntent.other,
      'ừm để xem': IssueIntent.unknown,
      'mất thuốc mà còn thấy mệt': IssueIntent.unknown, // two problems: do not guess
    };
    cases.forEach((said, expected) => test('"$said" → $expected', () => expect(classifyIssue(said), expected)));
  });
}
