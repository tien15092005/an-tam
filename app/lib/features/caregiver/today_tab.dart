import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/section_label.dart';
import '../../core/theme/tokens.dart';
import '../care/care_api.dart';
import '../elder/call_children.dart' show callNumber;
import '../groups/code_dialog.dart' show confirm;
import '../groups/groups_api.dart';
import '../medications/med_photo.dart';
import 'today_api.dart';

part 'today_parts.dart';

/// "Hôm nay" (plan §10), super-minimal: one sentence on how the day goes, then only what needs you,
/// then the day as short rows. Refreshes itself every 30 seconds while open.
class TodayTab extends ConsumerStatefulWidget {
  const TodayTab({super.key, required this.group, required this.elderUserId, required this.onElderChanged});

  final GroupDetail group;
  final int? elderUserId;
  final ValueChanged<int> onElderChanged;

  @override
  ConsumerState<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends ConsumerState<TodayTab> with WidgetsBindingObserver {
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
    return (groupId: widget.group.id, elderUserId: id, date: ymd(DateTime.now()));
  }

  void _reload() {
    if (!mounted) return;
    ref.invalidate(openAlertsProvider(widget.group.id));
    final day = _day;
    if (day != null) ref.invalidate(dayViewProvider(day));
  }

  Future<void> _mark(ElderDay day, DayView view, String time, List<DaySlot> slots) =>
      markDoses(context, ref, day, view, time, slots, onDone: _reload);

  void _openTime(ElderDay day, DayView view, String time) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final v = ref.watch(dayViewProvider(day)).value ?? view;
            final slots = v.byTime[time] ?? const <DaySlot>[];
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
              children: [
                Text('Liều $time', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                for (final s in slots)
                  SlotCard(
                    slot: s,
                    onMark: () => _mark(day, v, s.time, [s]),
                    onUndo: () => undoMark(context, ref, day, s, onDone: _reload),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final elders = widget.group.members.where((m) => m.role == GroupRole.elder).toList();
    final day = _day;
    final view = day == null ? null : ref.watch(dayViewProvider(day));
    final v = view?.value;
    final alerts = ref.watch(openAlertsProvider(widget.group.id)).value ?? const <AlertItem>[];

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
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
        children: [
          Row(
            children: [
              Expanded(child: Text('Hôm nay', style: text.headlineSmall?.copyWith(fontSize: 24))),
              if (v?.phone != null)
                IconButton.filledTonal(
                  tooltip: 'Gọi ${v!.callName}',
                  style: IconButton.styleFrom(backgroundColor: AppColors.primarySoft, foregroundColor: AppColors.primary),
                  onPressed: () => callNumber(v.phone!),
                  icon: const Icon(Icons.call),
                ),
            ],
          ),
          if (elders.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final e in elders)
                  ChoiceChip(
                    label: Text(e.displayName),
                    selected: e.userId == widget.elderUserId,
                    onSelected: (_) => widget.onElderChanged(e.userId),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (elders.isEmpty)
            _EmptyFamily(owner: widget.group.iAmOwner)
          else if (view == null || (view.isLoading && v == null))
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (v == null)
            _Message(icon: Icons.cloud_off, text: describeNetworkError(view.error!), onRetry: _reload)
          else ...[
            _Hero(view: v),
            const SizedBox(height: AppSpacing.lg),
            _NeedsYou(groupId: widget.group.id, view: v, alerts: alerts, onMark: (time, slots) => _mark(day!, v, time, slots)),
            const SectionLabel('Lịch hôm nay'),
            if (v.slots.isEmpty && v.exercises.isEmpty)
              const _Message(icon: Icons.event_available, text: 'Hôm nay không có lịch uống thuốc.')
            else
              Card(
                child: Column(
                  children: [
                    for (final e in v.byTime.entries)
                      _TimeRow(time: e.key, slots: e.value, onTap: () => _openTime(day!, v, e.key)),
                    for (final e in v.exercises) _ExerciseRow(exercise: e),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              v.missedLast7Days == 0
                  ? '7 ngày qua không có liều nào bị bỏ lỡ.'
                  : '7 ngày qua có ${v.missedLast7Days} liều chưa được xác nhận.',
              style: text.bodySmall?.copyWith(color: v.missedLast7Days == 0 ? AppColors.muted : AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}

/// Asks first, then marks the doses taken for the elder; their phone stops ringing.
Future<void> markDoses(
  BuildContext context,
  WidgetRef ref,
  ElderDay day,
  DayView view,
  String time,
  List<DaySlot> slots, {
  required VoidCallback onDone,
}) async {
  final names = slots.map((s) => s.name).join(', ');
  final ok = await confirm(
    context,
    title: 'Đánh dấu đã uống?',
    message:
        'Chỉ đánh dấu khi bạn chắc chắn ${view.callName} đã uống $names (giờ $time). '
        'Điện thoại của ${view.callName} sẽ ngừng nhắc lần này.',
    action: 'Đã uống',
  );
  if (!ok || !context.mounted) return;
  await _run(
    context,
    () => ref.read(todayApiProvider).mark(day, time, slots.map((s) => s.medicationId).toList()),
    done: 'Đã đánh dấu. Máy của ${view.callName} sẽ ngừng nhắc khi nhận được.',
    onDone: onDone,
  );
}

Future<void> undoMark(BuildContext context, WidgetRef ref, ElderDay day, DaySlot s, {required VoidCallback onDone}) async {
  final ok = await confirm(
    context,
    title: 'Hoàn tác?',
    message: 'Bỏ đánh dấu "đã uống" cho ${s.name} lúc ${s.time}.',
    action: 'Hoàn tác',
  );
  if (!ok || !context.mounted) return;
  await _run(context, () => ref.read(todayApiProvider).undo(day, s.doseLogId!), done: 'Đã hoàn tác', onDone: onDone);
}

Future<void> _run(
  BuildContext context,
  Future<void> Function() action, {
  required String done,
  required VoidCallback onDone,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    onDone();
    messenger.showSnackBar(SnackBar(content: Text(done)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(describeNetworkError(e))));
  }
}
