part of 'schedule_tab.dart';

class _AddChoice extends StatelessWidget {
  const _AddChoice({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.strong = false,
    this.iconColor,
    this.iconBackground,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool strong;
  final Color? iconColor;
  final Color? iconBackground;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fg = strong ? AppColors.onAccent : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: strong ? AppColors.primary : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: strong ? AppColors.onAccent.withValues(alpha: 0.16) : (iconBackground ?? AppColors.primarySoft),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: strong ? fg : (iconColor ?? AppColors.primary)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleSmall?.copyWith(color: fg)),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(color: strong ? fg.withValues(alpha: 0.85) : AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mon–Sun of this week; a dot under each day says how it went. A day opens its details.
class _WeekStrip extends ConsumerWidget {
  const _WeekStrip({required this.elder, required this.onTap});

  final ElderRef elder;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final start = _today.subtract(Duration(days: _today.weekday - 1));
    final days = [for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i)];
    final data = ref.watch(
      calendarProvider((groupId: elder.groupId, elderUserId: elder.elderUserId, from: ymd(days.first), to: ymd(days.last))),
    );
    final byDay = {for (final d in data.value ?? const <CalendarDay>[]) ymd(d.date): d};
    return Row(
      children: [
        for (final d in days)
          Expanded(
            child: Builder(
              builder: (context) {
                final today = d == _today;
                final info = byDay[ymd(d)];
                final dot = info?.dot;
                return Semantics(
                  button: true,
                  label: info?.semantics ?? 'Ngày ${d.day} tháng ${d.month}',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onTap(d),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: today ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _weekdays[d.weekday - 1],
                            style: text.labelMedium?.copyWith(color: today ? AppColors.onAccent : AppColors.muted),
                          ),
                          const SizedBox(height: 2),
                          Text('${d.day}', style: text.titleSmall?.copyWith(color: today ? AppColors.onAccent : AppColors.ink)),
                          const SizedBox(height: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: dot == null ? Colors.transparent : (today ? AppColors.onAccent : dot.$1),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Every medicine under the times of day it is taken: "SÁNG · 07:30".
class _MedicinesBySession extends ConsumerWidget {
  const _MedicinesBySession({required this.elder, required this.owner, required this.onEdit});

  final ElderRef elder;
  final bool owner;
  final ValueChanged<Medication> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return ref
        .watch(medicationsProvider(elder))
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(describeNetworkError(e)),
          data: (meds) {
            if (meds.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Icon(Icons.medication_outlined, size: 40, color: AppColors.muted),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        owner ? 'Chưa có thuốc nào. Bấm "+ Thêm" để chụp toa hoặc nhập tay.' : 'Chưa có thuốc nào.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            // session -> time -> medicines
            final bySession = <String, Map<String, List<Medication>>>{};
            for (final m in meds) {
              for (final t in m.times) {
                bySession.putIfAbsent(sessionOf(t), () => {}).putIfAbsent(t, () => []).add(m);
              }
            }
            final order = ['Sáng', 'Trưa', 'Chiều', 'Tối'].where(bySession.containsKey);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final session in order) ...[
                  SectionLabel('$session · ${(bySession[session]!.keys.toList()..sort()).join(', ')}'),
                  Card(
                    child: Column(
                      children: [
                        for (final t in bySession[session]!.keys.toList()..sort())
                          for (final m in bySession[session]![t]!)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
                              leading: m.images.isEmpty
                                  ? const NoMedPhoto(size: 44)
                                  : RemoteMedPhoto(url: m.images.first.url, size: 44),
                              title: Text(m.title, style: text.titleSmall),
                              subtitle: Text(
                                [
                                  if (m.dosage != null) m.dosage!,
                                  if (m.description.isNotEmpty) m.description,
                                  if (bySession[session]!.length > 1) t,
                                  if (!m.everyDay || m.endDate != null) scheduleSummary(m).split(' · ').first,
                                ].join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: owner ? const Icon(Icons.chevron_right) : null,
                              onTap: owner ? () => onEdit(m) : null,
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(
                  'Ảnh và mô tả chỉ để tham khảo. Nếu nghi ngờ, đối chiếu vỏ thuốc và hỏi dược sĩ, bác sĩ.',
                  style: text.bodySmall,
                ),
              ],
            );
          },
        );
  }
}

class _MonthSheet extends ConsumerStatefulWidget {
  const _MonthSheet({required this.elder, required this.onTap});

  final ElderRef elder;
  final ValueChanged<DateTime> onTap;

  @override
  ConsumerState<_MonthSheet> createState() => _MonthSheetState();
}

class _MonthSheetState extends ConsumerState<_MonthSheet> {
  late DateTime _anchor = DateTime(_today.year, _today.month, 1);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final first = _anchor;
    final last = DateTime(first.year, first.month + 1, 0);
    final from = first.subtract(Duration(days: first.weekday - 1));
    final to = last.add(Duration(days: 7 - last.weekday));
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Tháng trước',
              onPressed: () => setState(() => _anchor = DateTime(_anchor.year, _anchor.month - 1, 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text('${_months[_anchor.month]} ${_anchor.year}', textAlign: TextAlign.center, style: text.titleMedium),
            ),
            IconButton(
              tooltip: 'Tháng sau',
              onPressed: () => setState(() => _anchor = DateTime(_anchor.year, _anchor.month + 1, 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        _CalendarGrid(
          range: (groupId: widget.elder.groupId, elderUserId: widget.elder.elderUserId, from: ymd(from), to: ymd(to)),
          from: from,
          to: to,
          month: _anchor.month,
          onTap: widget.onTap,
        ),
        const _Legend(),
      ],
    );
  }
}

class _CalendarGrid extends ConsumerWidget {
  const _CalendarGrid({required this.range, required this.from, required this.to, this.month, required this.onTap});

  final CalendarRange range;
  final DateTime from;
  final DateTime to;

  /// Days of the neighbouring months are dimmed.
  final int? month;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final data = ref.watch(calendarProvider(range));
    final byDay = {for (final d in data.value ?? const <CalendarDay>[]) ymd(d.date): d};
    final days = [for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) d];
    final today = ymd(DateTime.now());
    return Column(
      children: [
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: text.labelMedium?.copyWith(color: AppColors.muted),
                ),
              ),
          ],
        ),
        if (data.isLoading && data.value == null) const LinearProgressIndicator(),
        if (data.hasError) Text(describeNetworkError(data.error!)),
        for (var i = 0; i < days.length; i += 7)
          Row(
            children: [
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
            ],
          ),
      ],
    );
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: text.titleSmall?.copyWith(color: dim ? AppColors.muted.withValues(alpha: 0.5) : AppColors.ink),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (dot != null)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: dot.$1, shape: BoxShape.circle),
                    ),
                  if ((info?.exercises ?? 0) > 0) ...[
                    const SizedBox(width: 2),
                    Icon(
                      Icons.directions_walk,
                      size: 12,
                      color: info!.exercisesDone == info!.exercises ? AppColors.ok : AppColors.muted,
                    ),
                  ],
                ],
              ),
            ],
          ),
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
    Widget item(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          item(AppColors.ok, 'Uống đủ'),
          item(AppColors.warn, 'Không uống được'),
          item(AppColors.danger, 'Chưa xác nhận'),
          item(AppColors.primary, 'Còn liều sắp tới'),
        ],
      ),
    );
  }
}

class _DaySheet extends ConsumerWidget {
  const _DaySheet({
    required this.group,
    required this.elderUserId,
    required this.day,
    required this.onAdd,
    required this.onChanged,
  });

  final GroupDetail group;
  final int elderUserId;
  final DateTime day;
  final VoidCallback onAdd;
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(child: Text('Ngày ${day.day}/${day.month}/${day.year}', style: text.titleLarge)),
            if (group.iAmOwner && !day.isBefore(_today))
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onAdd();
                },
                icon: const Icon(Icons.add),
                label: const Text('Thêm từ ngày này'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ref
            .watch(dayViewProvider(key))
            .when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(describeNetworkError(e)),
              data: (v) => DayDetails(
                view: v,
                onMark: (time, slots) => markDoses(context, ref, key, v, time, slots, onDone: reload),
                onUndo: (s) => undoMark(context, ref, key, s, onDone: reload),
              ),
            ),
      ],
    );
  }
}
