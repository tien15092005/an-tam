import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';
import '../care/care_api.dart';
import '../elder/call_children.dart' show callNumber;
import '../groups/code_dialog.dart' show confirm;
import '../groups/groups_api.dart';
import '../medications/med_photo.dart';
import 'today_api.dart';

/// "Hôm nay" (plan §10): pick an elder, see red alerts, progress, the day's timeline, and mark a dose
/// for them when they took it in front of you. Refreshes itself every 30 seconds while open.
class TodayTab extends ConsumerStatefulWidget {
  const TodayTab({super.key, required this.group, required this.elderUserId, required this.onElderChanged});

  final GroupDetail group;
  final int? elderUserId;
  final ValueChanged<int> onElderChanged;

  @override
  ConsumerState<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends ConsumerState<TodayTab> with WidgetsBindingObserver {
  int _daysBack = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _reload());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  ElderDay? get _day {
    final id = widget.elderUserId;
    if (id == null) return null;
    final d = DateTime.now().subtract(Duration(days: _daysBack));
    return (groupId: widget.group.id, elderUserId: id, date: ymd(d));
  }

  void _reload() {
    if (!mounted) return;
    ref.invalidate(openAlertsProvider(widget.group.id));
    final day = _day;
    if (day != null) ref.invalidate(dayViewProvider(day));
  }

  Future<void> _mark(ElderDay day, DayView view, String time, List<DaySlot> slots) =>
      markDoses(context, ref, day, view, time, slots, onDone: _reload);

  Future<void> _undo(ElderDay day, DaySlot s) => undoMark(context, ref, day, s, onDone: _reload);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final elders = widget.group.members.where((m) => m.role == GroupRole.elder).toList();
    final day = _day;

    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        if (day == null) return;
        try {
          await ref.read(dayViewProvider(day).future);
        } catch (_) {
          // The error is shown in the list.
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          OpenAlertsSection(groupId: widget.group.id),
          if (elders.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(widget.group.iAmOwner
                    ? 'Chưa có hồ sơ bố mẹ. Vào tab "Cài đặt" để thêm bố / mẹ và tạo mã ghép máy.'
                    : 'Nhóm chưa có hồ sơ bố mẹ. Trưởng nhóm sẽ thêm.'),
              ),
            ),
          if (elders.length > 1)
            Wrap(spacing: AppSpacing.sm, children: [
              for (final e in elders)
                ChoiceChip(
                  label: Text(e.displayName),
                  selected: e.userId == widget.elderUserId,
                  onSelected: (_) => widget.onElderChanged(e.userId),
                ),
            ]),
          if (day != null) ...[
            Row(children: [
              IconButton(
                tooltip: 'Ngày trước',
                onPressed: _daysBack >= 6 ? null : () => setState(() => _daysBack++),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _daysBack == 0 ? 'Hôm nay' : (_daysBack == 1 ? 'Hôm qua' : _dateLabel(DateTime.parse(day.date))),
                  textAlign: TextAlign.center,
                  style: text.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Ngày sau',
                onPressed: _daysBack == 0 ? null : () => setState(() => _daysBack--),
                icon: const Icon(Icons.chevron_right),
              ),
            ]),
            ref.watch(dayViewProvider(day)).when(
                  loading: () => const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => _Message(icon: Icons.cloud_off, text: describeNetworkError(e), onRetry: _reload),
                  data: (v) => DayDetails(
                    view: v,
                    onMark: (time, slots) => _mark(day, v, time, slots),
                    onUndo: (s) => _undo(day, s),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  static String _dateLabel(DateTime d) => 'Ngày ${d.day}/${d.month}';
}

/// Asks first, then marks the doses taken for the elder; their phone stops ringing.
Future<void> markDoses(BuildContext context, WidgetRef ref, ElderDay day, DayView view, String time, List<DaySlot> slots,
    {required VoidCallback onDone}) async {
  final names = slots.map((s) => s.name).join(', ');
  final ok = await confirm(context,
      title: 'Đánh dấu đã uống?',
      message: 'Chỉ đánh dấu khi bạn chắc chắn ${view.callName} đã uống $names (giờ $time). '
          'Điện thoại của ${view.callName} sẽ ngừng nhắc lần này.',
      action: 'Đã uống');
  if (!ok || !context.mounted) return;
  await _run(context, () => ref.read(todayApiProvider).mark(day, time, slots.map((s) => s.medicationId).toList()),
      done: 'Đã đánh dấu. Máy của ${view.callName} sẽ ngừng nhắc khi nhận được.', onDone: onDone);
}

Future<void> undoMark(BuildContext context, WidgetRef ref, ElderDay day, DaySlot s, {required VoidCallback onDone}) async {
  final ok = await confirm(context, title: 'Hoàn tác?', message: 'Bỏ đánh dấu "đã uống" cho ${s.name} lúc ${s.time}.', action: 'Hoàn tác');
  if (!ok || !context.mounted) return;
  await _run(context, () => ref.read(todayApiProvider).undo(day, s.doseLogId!), done: 'Đã hoàn tác', onDone: onDone);
}

Future<void> _run(BuildContext context, Future<void> Function() action, {required String done, required VoidCallback onDone}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    onDone();
    messenger.showSnackBar(SnackBar(content: Text(done)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(describeNetworkError(e))));
  }
}

/// One elder's day: progress, timeline with mark / undo, exercises. Used by "Hôm nay" and the calendar.
class DayDetails extends StatelessWidget {
  const DayDetails({super.key, required this.view, required this.onMark, required this.onUndo});

  final DayView view;
  final void Function(String time, List<DaySlot> slots) onMark;
  final ValueChanged<DaySlot> onUndo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = view.counts;
    final total = c['total'] ?? 0;
    final taken = c['taken'] ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(view.callName, style: text.titleLarge)),
              if (view.phone != null)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () => callNumber(view.phone!),
                  icon: const Icon(Icons.phone),
                  label: const Text('Gọi'),
                ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: 'Đã uống $taken trên $total lần',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : taken / total,
                  minHeight: 10,
                  color: AppColors.ok,
                  backgroundColor: AppColors.okSoft,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Đã uống $taken/$total', style: text.titleMedium),
            Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.xs, children: [
              if ((c['missed'] ?? 0) > 0) _Count('MISSED', c['missed']!),
              if ((c['notTaken'] ?? 0) > 0) _Count('NOT_TAKEN', c['notTaken']!),
              if ((c['due'] ?? 0) > 0) _Count('DUE', c['due']!),
              if ((c['upcoming'] ?? 0) > 0) _Count('UPCOMING', c['upcoming']!),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text(
              view.missedLast7Days == 0
                  ? '7 ngày qua: không có lần nào bị bỏ lỡ'
                  : '7 ngày qua: ${view.missedLast7Days} lần chưa có xác nhận',
              style: text.bodyMedium?.copyWith(color: view.missedLast7Days == 0 ? AppColors.muted : AppColors.danger),
            ),
          ]),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      if (view.slots.isEmpty)
        const _Message(icon: Icons.event_available, text: 'Không có lịch uống thuốc ngày này.'),
      for (final e in view.byTime.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
          child: Row(children: [
            Icon(Icons.access_time, color: AppColors.navy, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(e.key, style: text.titleMedium)),
            if (e.value.where((s) => s.canMark).length > 1)
              TextButton(
                onPressed: () => onMark(e.key, e.value.where((s) => s.canMark).toList()),
                child: const Text('Đánh dấu cả giờ này'),
              ),
          ]),
        ),
        for (final s in e.value) _SlotCard(slot: s, onMark: () => onMark(s.time, [s]), onUndo: () => onUndo(s)),
      ],
      if (view.exercises.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
          child: Text('Tập thể dục', style: text.titleMedium),
        ),
        for (final e in view.exercises)
          Card(
            child: ListTile(
              leading: const Icon(Icons.directions_walk, color: AppColors.ok),
              title: Text('${e.time} · ${e.title}${e.durationMin == null ? '' : ' (${e.durationMin} phút)'}'),
              subtitle: Row(children: [
                Icon(e.look.$1, size: 16, color: e.look.$3),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(e.loggedAt == null ? e.look.$2 : '${e.look.$2} lúc ${hhmmOf(e.loggedAt!)}',
                      style: TextStyle(color: e.look.$3)),
                ),
              ]),
            ),
          ),
      ],
      const SizedBox(height: AppSpacing.md),
      Text('Ảnh và mô tả chỉ để tham khảo. Nếu nghi ngờ, đối chiếu vỏ thuốc và hỏi dược sĩ, bác sĩ.',
          style: text.bodySmall?.copyWith(color: AppColors.muted)),
    ]);
  }
}

class _Count extends StatelessWidget {
  const _Count(this.status, this.n);
  final String status;
  final int n;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color, _) = statusStyle(status);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: AppSpacing.xs),
      Text('$label: $n', style: TextStyle(color: color)),
    ]);
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.slot, required this.onMark, required this.onUndo});

  final DaySlot slot;
  final VoidCallback onMark;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (icon, label, color, soft) = statusStyle(slot.status);
    final details = [slot.answeredBy, slot.checkText].whereType<String>().join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          slot.imageUrl == null ? const NoMedPhoto(size: 56) : RemoteMedPhoto(url: slot.imageUrl!, size: 56),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(slot.name, style: text.titleSmall),
              if (slot.dosage != null || slot.description != null)
                Text([slot.dosage, slot.description].whereType<String>().join(' · '), style: text.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: AppSpacing.xs),
                  Text(label, style: text.labelMedium?.copyWith(color: color)),
                ]),
              ),
              if (details.isNotEmpty) Text(details, style: text.bodySmall?.copyWith(color: AppColors.muted)),
            ]),
          ),
          if (slot.canMark)
            OutlinedButton.icon(
              // The theme's full-width minimum would make a button inside a Row infinitely wide.
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: onMark,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Đánh dấu'),
            )
          else if (slot.canUndo)
            TextButton.icon(onPressed: onUndo, icon: const Icon(Icons.undo, size: 18), label: const Text('Hoàn tác')),
        ]),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(children: [
          Icon(icon, size: 40, color: AppColors.muted),
          const SizedBox(height: AppSpacing.sm),
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ]),
      );
}
