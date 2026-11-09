import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

/// The four kinds of paper "Quét OCR" understands (plan §8).
enum DocumentType {
  prescription('PRESCRIPTION', 'Toa thuốc', 'Nhiều thuốc, liều, buổi uống, số ngày', 'OCR_PRESCRIPTION'),
  package('PACKAGE', 'Bao bì, vỏ hộp, vỉ thuốc', 'Tên và hàm lượng; liều và giờ uống bạn tự nhập', 'OCR_PACKAGE'),
  invoice('INVOICE', 'Hóa đơn nhà thuốc', 'Danh sách tên và số lượng; giờ uống bạn tự nhập', 'OCR_INVOICE'),
  other('OTHER', 'Khác', 'Tách được gì thì gợi ý nấy', 'OCR_PRESCRIPTION');

  const DocumentType(this.api, this.label, this.hint, this.source);
  final String api;
  final String label;
  final String hint;

  /// What the created medicines record as their origin.
  final String source;
}

/// A suggestion from the AI service. Fields the paper does not give are empty and listed in [uncertain].
class ParsedItem {
  ParsedItem({
    required this.name,
    this.strength,
    this.dosage,
    required this.times,
    this.days,
    this.quantity,
    this.note,
    required this.confidence,
    required this.uncertain,
  });

  String name;
  String? strength;
  String? dosage;
  List<String> times;
  int? days;
  final int? quantity;
  String? note;
  final double confidence;
  final Set<String> uncertain;

  factory ParsedItem.fromJson(Map<String, dynamic> j) => ParsedItem(
        name: j['name'] as String,
        strength: j['strength'] as String?,
        dosage: j['dosage'] as String?,
        times: ((j['times'] as List?) ?? const []).cast<String>().toList(),
        days: j['days'] as int?,
        quantity: j['quantity'] as int?,
        note: j['note'] as String?,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        uncertain: ((j['uncertain'] as List?) ?? const []).cast<String>().toSet(),
      );
}

/// Thrown when the AI service cannot help right now: the app offers manual entry instead.
class AiUnavailable implements Exception {
  const AiUnavailable(this.message);
  final String message;
}

class OcrApi {
  OcrApi(this._ref);
  final Ref _ref;

  Future<List<ParsedItem>> parse(int groupId, DocumentType type, String text) async {
    try {
      final r = await _ref.read(dioProvider).post<Map<String, dynamic>>(
            '/api/groups/$groupId/ocr/parse',
            data: {'documentType': type.api, 'text': text},
          );
      return ((r.data!['items'] as List?) ?? const []).map((j) => ParsedItem.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 503 || e.response == null) {
        throw const AiUnavailable('Chưa đọc được giấy tờ lúc này. Bạn có thể nhập tay.');
      }
      rethrow;
    }
  }
}

final ocrApiProvider = Provider<OcrApi>(OcrApi.new);
