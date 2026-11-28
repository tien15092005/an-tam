import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';
import '../groups/code_dialog.dart';
import 'med_photo.dart';
import '../ocr/ocr_scan_screen.dart';
import 'medications_api.dart';
import 'medications_screen.dart' show weekdayShort;

const _shapes = ['tròn', 'bầu dục', 'con nhộng', 'dài', 'vuông', 'tam giác', 'gói bột', 'nước'];
const _colors = ['trắng', 'vàng', 'cam', 'hồng', 'đỏ', 'xanh lá', 'xanh dương', 'nâu', 'hai màu'];

class _NewPhoto {
  _NewPhoto(this.kind, this.bytes, this.name);
  final ImageKind kind;
  final Uint8List bytes;
  final String name;
}

/// Add or edit one medication (owner only): what it is, what it looks like, and when to take it.
class MedicationFormScreen extends ConsumerStatefulWidget {
  const MedicationFormScreen(
      {super.key, required this.groupId, required this.elderUserId, this.existing, this.startDate});

  final int groupId;
  final int elderUserId;
  final Medication? existing;

  /// A new medicine starts on the day picked in the calendar (plan §10).
  final DateTime? startDate;

  @override
  ConsumerState<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends ConsumerState<MedicationFormScreen> {
  final _form = GlobalKey<FormState>();
  late final MedicationDraft _d =
      widget.existing == null
          ? MedicationDraft(times: ['08:00'], startDate: widget.startDate)
          : MedicationDraft.of(widget.existing!);
  late final _name = TextEditingController(text: _d.name);
  late final _strength = TextEditingController(text: _d.strength);
  late final _dosage = TextEditingController(text: _d.dosage ?? (widget.existing == null ? '1 viên' : null));
  late final _imprint = TextEditingController(text: _d.imprint);
  late final _description = TextEditingController(text: _d.pillDescription);
  late final _note = TextEditingController(text: _d.note);
  late final List<MedImage> _kept = [...?widget.existing?.images];
  final List<_NewPhoto> _added = [];
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    for (final c in [_name, _strength, _dosage, _imprint, _description, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Giờ uống',
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null) return;
    final s = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (!_d.times.contains(s)) _d.times = [..._d.times, s]..sort();
    });
  }

  Future<void> _pickDate({required bool end}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (end ? _d.endDate : _d.startDate) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: end ? 'Uống đến ngày' : 'Bắt đầu từ ngày',
    );
    if (picked != null) setState(() => end ? _d.endDate = picked : _d.startDate = picked);
  }

  Future<void> _addPhoto(ImageKind kind) async {
    if (_kept.length + _added.length >= 4) {
      _say('Mỗi thuốc tối đa 4 ảnh.');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    // Shrunk on the phone first so uploads stay small through the tunnel; the server re-encodes anyway.
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _added.add(_NewPhoto(kind, bytes, file.name)));
  }

  void _say(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_d.times.isEmpty) {
      _say('Cần ít nhất một giờ uống.');
      return;
    }
    _d
      ..name = _name.text.trim()
      ..strength = _t(_strength)
      ..dosage = _t(_dosage)
      ..imprint = _t(_imprint)
      ..pillDescription = _t(_description)
      ..note = _t(_note);
    setState(() => _saving = true);
    final api = ref.read(medicationsApiProvider);
    try {
      final saved = _editing
          ? await api.update(widget.groupId, widget.existing!.id, _d)
          : await api.create(widget.groupId, widget.elderUserId, _d);
      // An edit with history creates a new version; the server moves the photos across to it.
      final removed = widget.existing?.images.where((i) => !_kept.any((k) => k.id == i.id)) ?? const [];
      for (final img in removed) {
        await api.deleteImage(widget.groupId, saved.id, img.id);
      }
      for (final p in _added) {
        await api.addImage(widget.groupId, saved.id, p.kind, p.bytes, p.name);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _say(describeNetworkError(e));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(context,
        title: 'Xóa thuốc ${widget.existing!.name}?',
        message: 'Máy của bố mẹ sẽ không nhắc thuốc này nữa. Lịch sử các lần đã uống vẫn được giữ.',
        action: 'Xóa thuốc');
    if (!ok) return;
    setState(() => _saving = true);
    try {
      await ref.read(medicationsApiProvider).delete(widget.groupId, widget.existing!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _say(describeNetworkError(e));
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _choices(String label, List<String> options, String? value, ValueChanged<String?> onChanged) {
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: text.labelLarge),
      const SizedBox(height: AppSpacing.xs),
      Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
        for (final o in options)
          ChoiceChip(label: Text(o), selected: value == o, onSelected: (sel) => setState(() => onChanged(sel ? o : null))),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    String fmt(DateTime? d) => d == null ? '' : '${d.day}/${d.month}/${d.year}';
    const gap = SizedBox(height: AppSpacing.md);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Sửa thuốc' : 'Thêm thuốc'),
        actions: [
          if (_editing)
            IconButton(
                key: const Key('deleteMedication'),
                tooltip: 'Xóa thuốc',
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (!_editing) ...[
                // Two ways in on the same screen (plan §8): type it, or "Quét OCR".
                OutlinedButton.icon(
                  key: const Key('scanOcr'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: () async {
                    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
                      builder: (_) => OcrScanScreen(
                          groupId: widget.groupId, elderUserId: widget.elderUserId, startDate: widget.startDate),
                    ));
                    if (created == true && context.mounted) Navigator.of(context).pop(true);
                  },
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Quét OCR (toa thuốc, vỏ hộp, hóa đơn)'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('hoặc nhập tay', textAlign: TextAlign.center, style: text.bodySmall),
                gap,
              ],
              Text('Thuốc gì', style: text.titleMedium),
              gap,
              TextFormField(
                key: const Key('medName'),
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Tên thuốc *', hintText: 'Ví dụ: Amlodipin'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên thuốc' : null,
              ),
              gap,
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: _strength, decoration: const InputDecoration(labelText: 'Hàm lượng', hintText: '5mg'))),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                    child: TextFormField(
                        key: const Key('medDosage'),
                        controller: _dosage,
                        decoration: const InputDecoration(labelText: 'Mỗi lần uống', hintText: '1 viên'))),
              ]),
              const SizedBox(height: AppSpacing.lg),
              Text('Hình dạng để bố mẹ nhận ra', style: text.titleMedium),
              gap,
              _choices('Hình dạng', _shapes, _d.shape, (v) => _d.shape = v),
              gap,
              _choices('Màu', _colors, _d.color, (v) => _d.color = v),
              gap,
              TextFormField(
                  controller: _imprint, decoration: const InputDecoration(labelText: 'Chữ hoặc số khắc trên viên (nếu có)')),
              gap,
              TextFormField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Mô tả để máy đọc cho bố mẹ', hintText: 'Viên tròn nhỏ màu trắng, trong vỉ bạc'),
              ),
              gap,
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                for (final img in _kept)
                  _PhotoTile(
                      label: img.kind == ImageKind.pill ? 'Viên' : 'Bao bì',
                      onRemove: () => setState(() => _kept.remove(img)),
                      child: RemoteMedPhoto(url: img.url, size: 88)),
                for (final p in _added)
                  _PhotoTile(
                      label: p.kind == ImageKind.pill ? 'Viên' : 'Bao bì',
                      onRemove: () => setState(() => _added.remove(p)),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Image.memory(p.bytes, width: 88, height: 88, fit: BoxFit.cover))),
              ]),
              Wrap(spacing: AppSpacing.sm, children: [
                TextButton.icon(
                    onPressed: () => _addPhoto(ImageKind.pill),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Ảnh viên thuốc')),
                TextButton.icon(
                    onPressed: () => _addPhoto(ImageKind.package),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Ảnh bao bì')),
              ]),
              const SizedBox(height: AppSpacing.lg),
              Text('Khi nào uống', style: text.titleMedium),
              gap,
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                for (final t in _d.times)
                  InputChip(
                      label: Text(t, style: text.titleMedium),
                      onDeleted: () => setState(() => _d.times = _d.times.where((x) => x != t).toList())),
                ActionChip(
                    key: const Key('addTime'),
                    avatar: const Icon(Icons.add_alarm),
                    label: const Text('Thêm giờ'),
                    onPressed: _addTime),
              ]),
              gap,
              Text(_d.daysOfWeek.isEmpty ? 'Ngày uống: hằng ngày' : 'Ngày uống: chỉ những ngày đã chọn',
                  style: text.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Wrap(spacing: AppSpacing.xs, children: [
                for (final e in weekdayShort.entries)
                  FilterChip(
                    label: Text(e.value),
                    selected: _d.daysOfWeek.contains(e.key),
                    onSelected: (sel) => setState(() {
                      final days = {..._d.daysOfWeek};
                      sel ? days.add(e.key) : days.remove(e.key);
                      // All seven ticked is the same as every day.
                      _d.daysOfWeek = days.length == 7 ? [] : (days.toList()..sort());
                    }),
                  ),
              ]),
              gap,
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(end: false),
                    icon: const Icon(Icons.event),
                    label: Text(_d.startDate == null ? 'Từ hôm nay' : 'Từ ${fmt(_d.startDate)}'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(end: true),
                    icon: const Icon(Icons.event_busy),
                    label: Text(_d.endDate == null ? 'Uống lâu dài' : 'Đến ${fmt(_d.endDate)}'),
                  ),
                ),
              ]),
              if (_d.endDate != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => setState(() => _d.endDate = null), child: const Text('Bỏ ngày kết thúc')),
                ),
              gap,
              TextFormField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Ghi chú', hintText: 'Uống sau ăn, uống nhiều nước')),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const Key('saveMedication'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_editing ? 'Lưu thay đổi' : 'Lưu thuốc'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.label, required this.onRemove, required this.child});

  final String label;
  final VoidCallback onRemove;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(children: [
        child,
        Positioned(
          left: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(backgroundColor: Colors.black45, foregroundColor: Colors.white),
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
          ),
        ),
      ]);
}
