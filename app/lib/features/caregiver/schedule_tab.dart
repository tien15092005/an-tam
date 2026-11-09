import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';
import '../care/care_api.dart';
import '../exercises/exercise_form_screen.dart';
import '../exercises/exercises_api.dart';
import '../groups/code_dialog.dart' show confirm;
import '../groups/groups_api.dart';
import '../medications/medication_form_screen.dart';
import 'today_api.dart';
import 'today_tab.dart';

const _months = ['', 'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6', 'Tháng 7', 'Tháng 8', 'Tháng 9',
  'Tháng 10', 'Tháng 11', 'Tháng 12'];

/// "Lịch" (plan §10): week or month with a status dot per day; a day opens its details. The owner adds
/// medicines (with "Quét OCR" inside) and exercises starting on that day; members only look.
class ScheduleTab extends ConsumerStatefulWidget {
  const ScheduleTab({super.key, required this.group, required this.elderUserId, required this.onElderChanged});

  final GroupDetail group;
  final int? elderUserId;
  final ValueChanged<int> onElderChanged;

  @override
  ConsumerState<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends ConsumerState<ScheduleTab> {
  bool _month = false;
  late DateTime _anchor = _today;

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Monday-first grid covering the week or the month of [_anchor].
  (DateTime, DateTime) get _range {
    if (!_month) {
      final start = _anchor.subtract(Duration(days: _anchor.weekday - 1));
      return (start, start.add(const Duration(days: 6)));
    }
    final first = DateTime(_anchor.year, _anchor.month, 1);
    final last = DateTime(_anchor.year, _anchor.month + 1, 0);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final end = last.add(Duration(days: 7 - last.weekday));
    return (start, end);
  }

  void _shift(int dir) => setState(() {
        _anchor = _month
            ? DateTime(_anchor.year, _anchor.month + dir, 1)
            : _anchor.add(Duration(days: 7 * dir));
      });

  ElderRef? get _elder => widget.elderUserId == null ? null : (groupId: widget.group.id, elderUserId: widget.elderUserId!);

  void _reload() {
    ref.invalidate(calendarProvider);
    ref.invalidate(dayViewProvider);
    if (_elder != null) ref.invalidate(exercisesProvider(_elder!));
  }

  Future<void> _addMedication(DateTime start) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => MedicationFormScreen(groupId: widget.group.id, elderUserId: widget.elderUserId!, startDate: start),
    ));
    if (changed == true) _reload();
  }

  Future<void> _editExercise({Exercise? existing, DateTime? start}) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ExerciseFormScreen(
          groupId: widget.group.id, elderUserId: widget.elderUserId!, existing: existing, startDate: start),
    ));
    if (changed == true) _reload();
  }

  Future<void> _deleteExercise(Exercise e) async {
    if (!await confirm(context, title: 'Xóa lịch tập?', message: 'Máy của bố mẹ sẽ thôi nhắc "${e.title}".', action: 'Xóa')) {
      return;
    }
    try {
      await ref.read(exercisesApiProvider).delete(widget.group.id, e.id);
      _reload();
    } catch (err) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeNetworkError(err))));
    }
  }

  void _openDay(DateTime day) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _DaySheet(
          group: widget.group,
          elderUserId: widget.elderUserId!,
          day: day,
          onAddMedication: () => _addMedication(day),
          onAddExercise: () => _editExercise(start: day),
          onChanged: _reload,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final elders = widget.group.members.where((m) => m.role == GroupRole.elder).toList();
    final owner = widget.group.iAmOwner;
    final (from, to) = _range;
    final elder = _elder;

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
        if (elders.isEmpty) const Text('Chưa có hồ sơ bố mẹ. Vào tab "Cài đặt" để thêm.'),
        if (elders.length > 1)
          Wrap(spacing: AppSpacing.sm, children: [
            for (final e in elders)
              ChoiceChip(
                label: Text(e.displayName),
                selected: e.userId == widget.elderUserId,
                onSelected: (_) => widget.onElderChanged(e.userId),
              ),
          ]),
        if (elder != null) ...[
          Row(children: [
            IconButton(tooltip: _month ? 'Tháng trước' : 'Tuần trước', onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Text(
                _month ? '${_months[_anchor.month]} ${_anchor.year}' : '${from.day}/${from.month} – ${to.day}/${to.month}',
                textAlign: TextAlign.center,
                style: text.titleMedium,
              ),
            ),
            IconButton(tooltip: _month ? 'Tháng sau' : 'Tuần sau', onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
          ]),
          Center(
            child: SegmentedButton<bool>(
              segments: const [ButtonSegment(value: false, label: Text('Tuần')), ButtonSegment(value: true, label: Text('Tháng'))],
              selected: {_month},
              onSelectionChanged: (v) => setState(() => _month = v.first),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _CalendarGrid(
            range: (groupId: elder.groupId, elderUserId: elder.elderUserId, from: ymd(from), to: ymd(to)),
            from: from,
            to: to,
            month: _month ? _anchor.month : null,
            onTap: _openDay,
          ),
          const _Legend(),
          const SizedBox(height: AppSpacing.md),
          if (owner)
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _addMedication(_today),
                  icon: const Icon(Icons.medication),
                  label: const Text('Thêm thuốc'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _editExercise(start: _today),
                  icon: const Icon(Icons.directions_walk),
                  label: const Text('Thêm lịch tập'),
                ),
              ),
            ]),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: ListTile(
              leading: const Icon(Icons.medication_outlined),
              title: const Text('Danh sách thuốc và ảnh'),
              subtitle: Text(owner ? 'Xem, sửa, xóa thuốc' : 'Chỉ xem'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/groups/${elder.groupId}/elders/${elder.elderUserId}/medications'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Lịch tập', style: text.titleMedium),
          ref.watch(exercisesProvider(elder)).when(
                loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.md), child: LinearProgressIndicator()),
                error: (e, _) => Text(describeNetworkError(e)),
                data: (list) => Column(children: [
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Text(owner ? 'Chưa có lịch tập. Bấm "Thêm lịch tập".' : 'Chưa có lịch tập.'),
                    ),
                  for (final e in list)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.directions_walk, color: AppColors.ok),
                        title: Text(e.title),
                        subtitle: Text([
                          e.time,
                          weekdaysLabel(e.daysOfWeek),
                          if (e.durationMin != null) '${e.durationMin} phút',
                        ].join(' · ')),
                        trailing: owner
                            ? PopupMenuButton<String>(
                                onSelected: (v) => v == 'edit' ? _editExercise(existing: e) : _deleteExercise(e),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Sửa')),
                                  PopupMenuItem(value: 'delete', child: Text('Xóa')),
                                ],
                              )
                            : null,
                      ),
                    ),
                ]),
              ),
        ],
      ]),
    );
  }
}

class _CalendarGrid extends ConsumerWidget {
  const _CalendarGrid({required this.range, required this.from, required this.to, this.month, required this.onTap});

  final CalendarRange range;
  final DateTime from;
  final DateTime to;

  /// In month view, days of the neighbouring months are dimmed.
  final int? month;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final data = ref.watch(calendarProvider(range));
    final byDay = {for (final d in data.value ?? const <CalendarDay>[]) ymd(d.date): d};
    final days = [for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) d];
    final today = ymd(DateTime.now());
    return Column(children: [
      Row(children: [
        for (final w in const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
          Expanded(child: Text(w, textAlign: TextAlign.center, style: text.labelMedium?.copyWith(color: AppColors.muted))),
      ]),
      if (data.isLoading && data.value == null) const LinearProgressIndicator(),
      if (data.hasError) Text(describeNetworkError(data.error!)),
      for (var i = 0; i < days.length; i += 7)
        Row(children: [
          for (final d in days.sublist(i, i + 7))
            Expanded(
              child: _DayCell(
                day: d,
                info: byDay[ymd(d)],
                isToday: ymd(d) == today,
                dim: month != null && d.month != month,
                onTap: () => onTap(d),
              ),
            ),
        ]),
    ]);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, this.info, required this.isToday, required this.dim, required this.onTap});

  final DateTime day;
  final CalendarDay? info;
  final bool isToday;
  final bool dim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dot = info?.dot;
    return Semantics(
      button: true,
      label: info?.semantics ?? 'Ngày ${day.day} tháng ${day.month}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          height: 56,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: isToday ? Border.all(color: AppColors.primary, width: 2) : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${day.day}',
                style: text.titleSmall?.copyWith(color: dim ? AppColors.muted.withValues(alpha: 0.5) : AppColors.ink)),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (dot != null) Container(width: 10, height: 10, decoration: BoxDecoration(color: dot.$1, shape: BoxShape.circle)),
              if ((info?.exercises ?? 0) > 0) ...[
                const SizedBox(width: 2),
                Icon(Icons.directions_walk, size: 12,
                    color: info!.exercisesDone == info!.exercises ? AppColors.ok : AppColors.muted),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    Widget item(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: style),
        ]);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.xs, children: [
        item(AppColors.ok, 'Uống đủ'),
        item(AppColors.warn, 'Không uống được'),
        item(AppColors.danger, 'Chưa xác nhận'),
        item(AppColors.navy, 'Còn lần sắp tới'),
      ]),
    );
  }
}

class _DaySheet extends ConsumerWidget {
  const _DaySheet({
    required this.group,
    required this.elderUserId,
    required this.day,
    required this.onAddMedication,
    required this.onAddExercise,
    required this.onChanged,
  });

  final GroupDetail group;
  final int elderUserId;
  final DateTime day;
  final VoidCallback onAddMedication;
  final VoidCallback onAddExercise;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final key = (groupId: group.id, elderUserId: elderUserId, date: ymd(day));
    void reload() {
      ref.invalidate(dayViewProvider(key));
      ref.invalidate(openAlertsProvider(group.id));
      onChanged();
    }

    return ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg), children: [
      Text('Ngày ${day.day}/${day.month}/${day.year}', style: text.titleLarge),
      const SizedBox(height: AppSpacing.sm),
      if (group.iAmOwner)
        Wrap(spacing: AppSpacing.sm, children: [
          ActionChip(
            avatar: const Icon(Icons.medication, size: 18),
            label: const Text('Thêm thuốc từ ngày này'),
            onPressed: () {
              Navigator.pop(context);
              onAddMedication();
            },
          ),
          ActionChip(
            avatar: const Icon(Icons.directions_walk, size: 18),
            label: const Text('Thêm lịch tập từ ngày này'),
            onPressed: () {
              Navigator.pop(context);
              onAddExercise();
            },
          ),
        ]),
      ref.watch(dayViewProvider(key)).when(
            loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text(describeNetworkError(e)),
            data: (v) => DayDetails(
              view: v,
              onMark: (time, slots) => markDoses(context, ref, key, v, time, slots, onDone: reload),
              onUndo: (s) => undoMark(context, ref, key, s, onDone: reload),
            ),
          ),
    ]);
  }
}
