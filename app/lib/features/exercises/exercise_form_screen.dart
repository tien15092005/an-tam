import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';
import 'exercises_api.dart';

/// Add or edit an exercise reminder (owner only; the server checks too).
class ExerciseFormScreen extends ConsumerStatefulWidget {
  const ExerciseFormScreen({super.key, required this.groupId, required this.elderUserId, this.existing, this.startDate});

  final int groupId;
  final int elderUserId;
  final Exercise? existing;
  final DateTime? startDate;

  @override
  ConsumerState<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends ConsumerState<ExerciseFormScreen> {
  final _form = GlobalKey<FormState>();
  late final ExerciseDraft _d =
      widget.existing == null ? ExerciseDraft(startDate: widget.startDate) : ExerciseDraft.of(widget.existing!);
  late final _title = TextEditingController(text: _d.title);
  late final _duration = TextEditingController(text: _d.durationMin?.toString() ?? '');
  late final _note = TextEditingController(text: _d.note);
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final parts = _d.time.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked != null) {
      setState(() => _d.time = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _pickDate({required bool end}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (end ? _d.endDate : _d.startDate) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => end ? _d.endDate = picked : _d.startDate = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _d.title = _title.text;
    _d.durationMin = int.tryParse(_duration.text.trim());
    _d.note = _note.text;
    setState(() => _saving = true);
    final api = ref.read(exercisesApiProvider);
    try {
      if (widget.existing == null) {
        await api.create((groupId: widget.groupId, elderUserId: widget.elderUserId), _d);
      } else {
        await api.update(widget.groupId, widget.existing!.id, _d);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeNetworkError(e))));
      }
    }
  }

  String _date(DateTime? d) => d == null ? 'Không đặt' : '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final everyDay = _d.daysOfWeek.isEmpty || _d.daysOfWeek.length == 7;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Thêm lịch tập' : 'Sửa lịch tập')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Bài tập, ví dụ: Đi bộ quanh nhà'),
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên bài tập' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time),
            title: const Text('Giờ tập'),
            trailing: Text(_d.time, style: text.titleMedium),
            onTap: _pickTime,
          ),
          Text('Ngày trong tuần', style: text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
            FilterChip(
              label: const Text('Hằng ngày'),
              selected: everyDay,
              onSelected: (_) => setState(() => _d.daysOfWeek = []),
            ),
            for (final d in weekdayShort.entries)
              FilterChip(
                label: Text(d.value),
                selected: !everyDay && _d.daysOfWeek.contains(d.key),
                onSelected: (on) => setState(() {
                  final days = everyDay ? <int>[] : [..._d.daysOfWeek];
                  on ? days.add(d.key) : days.remove(d.key);
                  days.sort();
                  _d.daysOfWeek = days;
                }),
              ),
          ]),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Thời lượng (phút, không bắt buộc)'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final n = int.tryParse(v.trim());
              return (n == null || n < 1 || n > 240) ? 'Từ 1 đến 240 phút' : null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Ghi chú, ví dụ: đi chậm, mang gậy'),
            maxLength: 300,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('Bắt đầu'),
            trailing: Text(_d.startDate == null ? 'Hôm nay' : _date(_d.startDate)),
            onTap: () => _pickDate(end: false),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy),
            title: const Text('Kết thúc'),
            trailing: Text(_date(_d.endDate)),
            onTap: () => _pickDate(end: true),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Đang lưu...' : 'Lưu')),
          const SizedBox(height: AppSpacing.sm),
          Text('Máy của bố mẹ sẽ báo vào giờ này và hiện nút "TÔI ĐI TẬP ĐÂY".', style: text.bodySmall),
        ]),
      ),
    );
  }
}
