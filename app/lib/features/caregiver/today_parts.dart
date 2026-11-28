part of 'today_tab.dart';

class _EmptyFamily extends StatelessWidget {
  const _EmptyFamily({required this.owner});
  final bool owner;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.elderly, color: AppColors.primary, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              owner
                  ? 'Chưa có hồ sơ bố mẹ. Vào tab "Gia đình" để thêm bố / mẹ và lấy mã ghép máy.'
                  : 'Chưa có hồ sơ bố mẹ. Người đặt lịch thuốc sẽ thêm.',
            ),
          ),
        ],
      ),
    ),
  );
}

/// "Bà Lan đã uống 3/6 liều" with one bar piece per dose, coloured by its status, and the next dose.
class _Hero extends StatelessWidget {
  const _Hero({required this.view});
  final DayView view;

  static const _weekday = {1: 'Thứ Hai', 2: 'Thứ Ba', 3: 'Thứ Tư', 4: 'Thứ Năm', 5: 'Thứ Sáu', 6: 'Thứ Bảy', 7: 'Chủ Nhật'};

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = view.slots.length;
    final taken = view.slots.where((s) => s.status == 'TAKEN').length;
    final next = view.byTime.entries.where((e) => e.value.any((s) => s.status == 'UPCOMING' || s.status == 'DUE')).firstOrNull;
    final d = view.date;
    final headline = total == 0
        ? '${view.callName} hôm nay không có thuốc'
        : taken == total
        ? '${view.callName} đã uống đủ thuốc hôm nay'
        : '${view.callName} đã uống $taken/$total liều';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                InitialAvatar(view.callName, size: 44, strong: true),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_weekday[d.weekday]}, ${d.day}/${d.month}', style: text.bodySmall),
                      Text(headline, style: text.titleMedium?.copyWith(fontSize: 19, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            if (total > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                label: 'Đã uống $taken trên $total liều',
                excludeSemantics: true,
                child: Row(
                  children: [
                    for (var i = 0; i < view.slots.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: _barColor(view.slots[i].status),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (next != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Liều tiếp theo '),
                    TextSpan(
                      text: next.key,
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                    TextSpan(text: ' · ${next.value.map((s) => s.name).join(', ')}'),
                  ],
                ),
                style: text.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _barColor(String status) => switch (status) {
    'TAKEN' => AppColors.ok,
    'MISSED' => AppColors.danger,
    'NOT_TAKEN' => AppColors.warn,
    'DUE' => AppColors.primary,
    _ => AppColors.line,
  };
}

/// "Cần bạn xem": doses nobody confirmed and problems the parent reported. Hidden when all is well.
class _NeedsYou extends ConsumerWidget {
  const _NeedsYou({required this.groupId, required this.view, required this.alerts, required this.onMark});

  final int groupId;
  final DayView view;
  final List<AlertItem> alerts;
  final void Function(String time, List<DaySlot> slots) onMark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missed = <String, List<DaySlot>>{
      for (final e in view.byTime.entries)
        if (e.value.any((s) => s.status == 'MISSED' && s.canMark)) e.key: e.value.where((s) => s.status == 'MISSED').toList(),
    };
    // A "chưa xác nhận" alert for a dose already shown above would say the same thing twice.
    final others = alerts.where((a) => !(a.kind == 'NOT_CONFIRMED' && missed.containsKey(a.scheduledTime))).toList();
    final count = missed.length + others.length;
    if (count == 0) return const SizedBox.shrink();

    Future<void> resolve(AlertItem a) async {
      try {
        await resolveAlert(ref, groupId, a.id);
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeNetworkError(e))));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('Cần bạn xem · $count', color: AppColors.danger),
        for (final e in missed.entries)
          _AttentionCard(
            strong: true,
            title: 'Chưa xác nhận liều ${e.key}',
            subtitle:
                '${e.value.map((s) => [s.name, s.dosage].whereType<String>().join(' ')).join(', ')} · '
                'quá ${_minutesSince(view.date, e.key)} phút',
            actions: [
              if (view.phone != null)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => callNumber(view.phone!),
                    icon: const Icon(Icons.call, size: 18),
                    label: Text('Gọi ${_short(view.callName)}'),
                  ),
                ),
              if (view.phone != null) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => onMark(e.key, e.value.where((s) => s.canMark).toList()),
                  child: const Text('Đánh dấu đã uống'),
                ),
              ),
            ],
          ),
        for (final a in others)
          _AttentionCard(
            icon: a.icon,
            title: a.sentence,
            subtitle: 'Lúc ${hhmmOf(a.createdAt)} ngày ${a.createdAt.day}/${a.createdAt.month}',
            trailing: TextButton(onPressed: () => resolve(a), child: const Text('Đã xử lý')),
          ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  static String _short(String callName) {
    final w = callName.trim().split(RegExp(r'\s+'));
    return w.isEmpty ? callName : w.first.toLowerCase();
  }

  static int _minutesSince(DateTime date, String hhmm) {
    final p = hhmm.split(':');
    final due = DateTime(date.year, date.month, date.day, int.parse(p[0]), int.parse(p[1]));
    return DateTime.now().difference(due).inMinutes.clamp(0, 24 * 60);
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.title,
    required this.subtitle,
    this.icon,
    this.actions,
    this.trailing,
    this.strong = false,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final List<Widget>? actions;
  final Widget? trailing;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: strong ? AppColors.danger : AppColors.line, width: strong ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[Icon(icon, color: AppColors.danger, size: 26), const SizedBox(width: AppSpacing.sm)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleSmall),
                    Text(subtitle, style: text.bodySmall),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (actions != null) ...[const SizedBox(height: AppSpacing.sm), Row(children: actions!)],
        ],
      ),
    );
  }
}

/// One alarm time of the day: "07:30 · Amlodipin, Vitamin B · ✓ Đã uống".
class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.time, required this.slots, required this.onTap});

  final String time;
  final List<DaySlot> slots;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // The worst status of the time decides the label: one unconfirmed medicine makes the row red.
    const order = ['MISSED', 'NOT_TAKEN', 'DUE', 'UPCOMING', 'SKIPPED', 'TAKEN'];
    final status = order.firstWhere((o) => slots.any((s) => s.status == o), orElse: () => slots.first.status);
    final (icon, label, color, _) = statusStyle(status);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(time, style: text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            ),
            Expanded(
              child: Text(
                slots.map((s) => s.name).join(', '),
                style: text.bodyLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              status == 'UPCOMING' ? 'Sắp tới' : label,
              style: text.labelMedium?.copyWith(color: status == 'UPCOMING' ? AppColors.muted : color),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});
  final DayExercise exercise;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final e = exercise;
    final (icon, label, color) = e.look;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
      child: Row(
        children: [
          SizedBox(width: 52, child: Text(e.time, style: text.titleSmall)),
          Icon(Icons.directions_walk, size: 18, color: AppColors.ok),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${e.title}${e.durationMin == null ? '' : ' ${e.durationMin} phút'}',
              style: text.bodyLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: text.labelMedium?.copyWith(color: color)),
        ],
      ),
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(view.callName, style: text.titleLarge)),
                    if (view.phone != null)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                        onPressed: () => callNumber(view.phone!),
                        icon: const Icon(Icons.phone),
                        label: const Text('Gọi'),
                      ),
                  ],
                ),
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
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if ((c['missed'] ?? 0) > 0) _Count('MISSED', c['missed']!),
                    if ((c['notTaken'] ?? 0) > 0) _Count('NOT_TAKEN', c['notTaken']!),
                    if ((c['due'] ?? 0) > 0) _Count('DUE', c['due']!),
                    if ((c['upcoming'] ?? 0) > 0) _Count('UPCOMING', c['upcoming']!),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  view.missedLast7Days == 0
                      ? '7 ngày qua: không có lần nào bị bỏ lỡ'
                      : '7 ngày qua: ${view.missedLast7Days} lần chưa có xác nhận',
                  style: text.bodyMedium?.copyWith(color: view.missedLast7Days == 0 ? AppColors.muted : AppColors.danger),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (view.slots.isEmpty) const _Message(icon: Icons.event_available, text: 'Không có lịch uống thuốc ngày này.'),
        for (final e in view.byTime.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
            child: Row(
              children: [
                Icon(Icons.access_time, color: AppColors.navy, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(e.key, style: text.titleMedium)),
                if (e.value.where((s) => s.canMark).length > 1)
                  TextButton(
                    onPressed: () => onMark(e.key, e.value.where((s) => s.canMark).toList()),
                    child: const Text('Đánh dấu cả giờ này'),
                  ),
              ],
            ),
          ),
          for (final s in e.value) SlotCard(slot: s, onMark: () => onMark(s.time, [s]), onUndo: () => onUndo(s)),
        ],
        if (view.exercises.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
            child: Text('Tập thể dục', style: text.titleMedium),
          ),
          for (final e in view.exercises)
            Card(
              child: ListTile(
                leading: Icon(Icons.directions_walk, color: AppColors.ok),
                title: Text('${e.time} · ${e.title}${e.durationMin == null ? '' : ' (${e.durationMin} phút)'}'),
                subtitle: Row(
                  children: [
                    Icon(e.look.$1, size: 16, color: e.look.$3),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        e.loggedAt == null ? e.look.$2 : '${e.look.$2} lúc ${hhmmOf(e.loggedAt!)}',
                        style: TextStyle(color: e.look.$3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          'Ảnh và mô tả chỉ để tham khảo. Nếu nghi ngờ, đối chiếu vỏ thuốc và hỏi dược sĩ, bác sĩ.',
          style: text.bodySmall?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.status, this.n);
  final String status;
  final int n;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color, _) = statusStyle(status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text('$label: $n', style: TextStyle(color: color)),
      ],
    );
  }
}

class SlotCard extends StatelessWidget {
  const SlotCard({super.key, required this.slot, required this.onMark, required this.onUndo});

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            slot.imageUrl == null ? const NoMedPhoto(size: 56) : RemoteMedPhoto(url: slot.imageUrl!, size: 56),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slot.name, style: text.titleSmall),
                  if (slot.dosage != null || slot.description != null)
                    Text([slot.dosage, slot.description].whereType<String>().join(' · '), style: text.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: color),
                        const SizedBox(width: AppSpacing.xs),
                        Text(label, style: text.labelMedium?.copyWith(color: color)),
                      ],
                    ),
                  ),
                  if (details.isNotEmpty) Text(details, style: text.bodySmall?.copyWith(color: AppColors.muted)),
                ],
              ),
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
          ],
        ),
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
    child: Column(
      children: [
        Icon(icon, size: 40, color: AppColors.muted),
        const SizedBox(height: AppSpacing.sm),
        Text(text, textAlign: TextAlign.center),
        if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}
