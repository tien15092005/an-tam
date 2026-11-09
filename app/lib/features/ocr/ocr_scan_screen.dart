import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';
import '../../domain/pii_filter.dart';
import 'ocr_api.dart';
import 'ocr_review_screen.dart';

/// "Quét OCR" (plan §8): choose the kind of paper → photo → crop → the phone reads the text itself →
/// personal lines are removed → suggestions → mandatory review. The photo never leaves the phone unless
/// the caregiver later ticks "Dùng ảnh này cho người già".
class OcrScanScreen extends ConsumerStatefulWidget {
  const OcrScanScreen({super.key, required this.groupId, required this.elderUserId, this.startDate});

  final int groupId;
  final int elderUserId;
  final DateTime? startDate;

  @override
  ConsumerState<OcrScanScreen> createState() => _OcrScanScreenState();
}

class _OcrScanScreenState extends ConsumerState<OcrScanScreen> {
  DocumentType _type = DocumentType.prescription;
  String? _status;
  bool _busy = false;

  Future<void> _scan(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 2400, maxHeight: 2400, imageQuality: 92);
    if (picked == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Cắt lấy phần có chữ',
          toolbarColor: AppColors.navy,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
        ),
      ],
    );
    final path = cropped?.path ?? picked.path;
    setState(() {
      _busy = true;
      _status = 'Đang đọc chữ trên máy...';
    });
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    String text;
    try {
      text = (await recognizer.processImage(InputImage.fromFilePath(path))).text;
    } catch (e) {
      _fail('Không đọc được chữ trong ảnh. Hãy chụp lại rõ hơn, hoặc nhập tay.');
      return;
    } finally {
      await recognizer.close();
    }
    final filtered = removePersonalLines(text);
    if (filtered.text.trim().isEmpty) {
      _fail('Ảnh không có chữ đọc được. Hãy chụp gần và đủ sáng hơn.');
      return;
    }
    setState(() => _status = 'Đang tách thông tin thuốc...');
    List<ParsedItem> items;
    try {
      items = await ref.read(ocrApiProvider).parse(widget.groupId, _type, filtered.text);
    } on AiUnavailable catch (e) {
      _fail(e.message, offerManual: true);
      return;
    } catch (e) {
      _fail(describeNetworkError(e), offerManual: true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = null;
    });
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => OcrReviewScreen(
        groupId: widget.groupId,
        elderUserId: widget.elderUserId,
        type: _type,
        items: items,
        imagePath: path,
        removedLines: filtered.removed,
        startDate: widget.startDate,
      ),
    ));
    if (created == true && mounted) Navigator.of(context).pop(true);
  }

  void _fail(String message, {bool offerManual = false}) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = null;
    });
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(message),
        actions: [
          if (offerManual)
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                Navigator.of(context).pop(false); // back to the manual form
              },
              child: const Text('Nhập tay'),
            ),
          FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Thử lại')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Quét OCR')),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
        Text('Loại giấy tờ', style: text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        RadioGroup<DocumentType>(
          groupValue: _type,
          onChanged: (v) => setState(() => _type = v ?? _type),
          child: Column(children: [
            for (final t in DocumentType.values)
              RadioListTile<DocumentType>(value: t, title: Text(t.label), subtitle: Text(t.hint)),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_busy) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: AppSpacing.sm),
          Text(_status ?? '', textAlign: TextAlign.center),
        ] else ...[
          FilledButton.icon(
            onPressed: () => _scan(ImageSource.camera),
            icon: const Icon(Icons.photo_camera),
            label: const Text('Chụp ảnh'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _scan(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Chọn ảnh có sẵn'),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Card(
          color: AppColors.navySoft,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Chữ được đọc ngay trên điện thoại. Dòng có họ tên, địa chỉ, số điện thoại, số thẻ được xóa trước khi gửi. '
              'Ảnh không gửi lên máy chủ. Kết quả chỉ là gợi ý: bạn kiểm tra và sửa từng thuốc trước khi lưu.',
              style: text.bodySmall,
            ),
          ),
        ),
        if (Platform.isIOS) const Text('Trên iPhone, Quét OCR chưa được thử.'),
      ]),
    );
  }
}
