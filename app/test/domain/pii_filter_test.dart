import 'package:app/domain/pii_filter.dart';
import 'package:app/features/ocr/ocr_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lines naming the patient, address, phone or card numbers never leave the phone', () {
    const text = 'ĐƠN THUỐC\nHọ tên: Nguyễn Văn Mẫu\nĐịa chỉ: 12 Lê Lợi\nSĐT: 0912 345 678\n'
        'Số thẻ BHYT HC4790123456789\nChẩn đoán: Tăng huyết áp\n1. Amlodipin 5mg 30 viên\nSáng 1 viên';
    final r = removePersonalLines(text);
    expect(r.text, isNot(contains('Nguyễn')));
    expect(r.text, isNot(contains('Lê Lợi')));
    expect(r.text, isNot(contains('0912')));
    expect(r.text, isNot(contains('HC479')));
    expect(r.text, isNot(contains('Tăng huyết áp')));
    expect(r.text, contains('Amlodipin 5mg'));
    expect(r.text, contains('Sáng 1 viên'));
    expect(r.removed, 5);
  });

  test('medicine lines with numbers are kept', () {
    for (final line in ['2) Metformin 500mg x 60 viên', 'Ngày 2 lần, mỗi lần 1 viên', 'Hộp 3 vỉ x 10 viên']) {
      expect(isPersonalLine(line), isFalse, reason: line);
    }
  });

  test('a suggestion keeps empty what the paper does not say', () {
    final item = ParsedItem.fromJson({
      'name': 'Atorvastatin', 'strength': '10mg', 'dosage': null, 'times': [], 'days': null, 'quantity': 30,
      'note': null, 'confidence': 0.4, 'uncertain': ['times', 'dosage', 'days'],
    });
    expect(item.times, isEmpty);
    expect(item.dosage, isNull);
    expect(item.uncertain, {'times', 'dosage', 'days'});
    expect(DocumentType.package.source, 'OCR_PACKAGE');
  });
}
