import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';
import '../medications/medications_api.dart';
import 'ocr_api.dart';

/// The mandatory review (plan §8): every field editable, the photo beside the result, fields the paper does
/// not state left empty and highlighted. Nothing is created until the caregiver presses save here.
class OcrReviewScreen extends ConsumerStatefulWidget {
  const OcrReviewScreen({
    super.key,
    required this.groupId,
    required this.elderUserId,
    required this.type,
    required this.items,
    required this.imagePath,
    required this.removedLines,
    this.startDate,
  });

  final int groupId;
  final int elderUserId;
  final DocumentType type;
  final List<ParsedItem> items;
  final String imagePath;
  final int removedLines;
  final DateTime? startDate;

  @override
  ConsumerState<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends ConsumerState<OcrReviewScreen> {
  late final List<bool> _keep = [for (final _ in widget.items) true];
  late DateTime _start = widget.startDate ?? DateUtils.dateOnly(DateTime.now());
  bool _usePhoto = false;
  bool _saving = false;
  bool _showPhoto = true;

  int get _kept => _keep.where((k) => k).length;

  Future<void> _addTime(ParsedItem item) async {
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t == null) return;
    final s = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (!item.times.contains(s)) item.times = [...item.times, s]..sort();
      item.uncertain.remove('times');
    });
  }

  Future<void> _save() async {
    final chosen = [for (var i = 0; i < widget.items.length; i++) if (_keep[i]) widget.items[i]];
    for (final it in chosen) {
      if (it.name.trim().isEmpty) return _say('Có thuốc chưa có tên.');
      if (it.times.isEmpty) return _say('Chọn giờ uống cho ${it.name}: giấy tờ không ghi, app không tự đoán.');
    }
    setState(() => _saving = true);
    final api = ref.read(medicationsApiProvider);
    try {
      for (final it in chosen) {
        final d = MedicationDraft(
          name: it.name.trim(),
          strength: _blank(it.strength),
          dosage: _blank(it.dosage),
          note: _blank(it.note),
          times: it.times,
          startDate: _start,
          endDate: it.days == null ? null : _start.add(Duration(days: it.days! - 1)),
        )..source = widget.type.source;
        final m = await api.create(widget.groupId, widget.elderUserId, d);
        if (_usePhoto && chosen.length == 1) {
          final bytes = await File(widget.imagePath).readAsBytes();
          await api.addImage(widget.groupId, m.id, ImageKind.package, bytes, 'scan.jpg');
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã thêm ${chosen.length} thuốc.')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _say(describeNetworkError(e));
      }
    }
  }

  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  static String? _blank(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Kiểm tra kết quả')),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
        Card(
          color: AppColors.warnSoft,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Đối chiếu từng thuốc với giấy tờ. Ô viền vàng là chỗ giấy tờ không ghi rõ: app để trống, bạn tự điền. '
              'Nếu nghi ngờ, hỏi dược sĩ hoặc bác sĩ.'
              '${widget.removedLines > 0 ? ' Đã bỏ ${widget.removedLines} dòng có thông tin cá nhân.' : ''}',
            ),
          ),
        ),
        Row(children: [
          Text('Ảnh gốc', style: text.titleMedium),
          const Spacer(),
          TextButton(onPressed: () => setState(() => _showPhoto = !_showPhoto), child: Text(_showPhoto ? 'Ẩn' : 'Hiện')),
        ]),
        if (_showPhoto)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InteractiveViewer(
              maxScale: 5,
              child: Image.file(File(widget.imagePath), height: 260, fit: BoxFit.contain),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: const Text('Bắt đầu uống từ'),
          trailing: Text('${_start.day}/${_start.month}/${_start.year}', style: text.titleMedium),
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
                context: context, initialDate: _start, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 2));
            if (d != null) setState(() => _start = d);
          },
        ),
        if (widget.items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text('Không tìm thấy thuốc nào trong ảnh. Hãy chụp lại rõ hơn, hoặc quay lại để nhập tay.'),
          ),
        for (var i = 0; i < widget.items.length; i++)
          _ItemCard(
            item: widget.items[i],
            keep: _keep[i],
            onKeep: (v) => setState(() => _keep[i] = v),
            onAddTime: () => _addTime(widget.items[i]),
            onChanged: () => setState(() {}),
          ),
        if (_kept == 1)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _usePhoto,
            onChanged: (v) => setState(() => _usePhoto = v ?? false),
            title: const Text('Dùng ảnh này cho người già'),
            subtitle: const Text('Ảnh sẽ được gửi lên để máy của bố mẹ hiện khi nhắc thuốc.'),
          ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _saving || _kept == 0 ? null : _save,
          child: Text(_saving ? 'Đang lưu...' : 'Lưu $_kept thuốc'),
        ),
      ]),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.keep, required this.onKeep, required this.onAddTime, required this.onChanged});

  final ParsedItem item;
  final bool keep;
  final ValueChanged<bool> onKeep;
  final VoidCallback onAddTime;
  final VoidCallback onChanged;

  InputDecoration _deco(String label, bool unsure) => InputDecoration(
        labelText: label,
        helperText: unsure ? 'Giấy tờ không ghi rõ, hãy tự điền' : null,
        helperStyle: TextStyle(color: AppColors.warn),
        enabledBorder: unsure
            ? OutlineInputBorder(borderSide: BorderSide(color: AppColors.warn, width: 2), borderRadius: BorderRadius.circular(AppRadius.sm))
            : null,
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final unsureTimes = item.times.isEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: keep,
            onChanged: (v) => onKeep(v ?? false),
            title: Text(item.name.isEmpty ? 'Thuốc' : item.name, style: text.titleMedium),
            subtitle: Text(keep ? 'Sẽ thêm thuốc này' : 'Bỏ qua thuốc này'),
          ),
          if (keep) ...[
            TextFormField(
              initialValue: item.name,
              decoration: _deco('Tên thuốc', item.name.trim().isEmpty),
              onChanged: (v) {
                item.name = v;
                onChanged();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(
                child: TextFormField(
                  initialValue: item.strength,
                  decoration: _deco('Hàm lượng', false),
                  onChanged: (v) => item.strength = v,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  initialValue: item.dosage,
                  decoration: _deco('Liều mỗi lần', item.dosage == null || item.dosage!.isEmpty),
                  onChanged: (v) {
                    item.dosage = v;
                    onChanged();
                  },
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Text('Giờ uống', style: text.titleSmall?.copyWith(color: unsureTimes ? AppColors.warn : null)),
            Wrap(spacing: AppSpacing.xs, children: [
              for (final t in item.times)
                InputChip(
                  label: Text(t),
                  onDeleted: () {
                    item.times = [...item.times]..remove(t);
                    onChanged();
                  },
                ),
              ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Thêm giờ'), onPressed: onAddTime),
            ]),
            if (unsureTimes)
              Text('Giấy tờ không ghi giờ uống: bấm "Thêm giờ" theo lời dặn của bác sĩ.',
                  style: text.bodySmall?.copyWith(color: AppColors.warn)),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(
                child: TextFormField(
                  initialValue: item.days?.toString(),
                  keyboardType: TextInputType.number,
                  decoration: _deco('Số ngày dùng', item.days == null),
                  onChanged: (v) {
                    item.days = int.tryParse(v.trim());
                    onChanged();
                  },
                ),
              ),
              if (item.quantity != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text('Số lượng trên giấy: ${item.quantity}'),
              ],
            ]),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              initialValue: item.note,
              decoration: _deco('Ghi chú, ví dụ: uống sau ăn', false),
              onChanged: (v) => item.note = v,
            ),
          ],
        ]),
      ),
    );
  }
}
