part of 'elder_home_screen.dart';

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.background, required this.text, this.onTap});

  final IconData icon;
  final Color color;
  final Color background;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: background,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
            if (onTap != null) Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    ),
  );
}

void _showDose(BuildContext context, DoseSlot slot) {
  final m = slot.med;
  final speech = [
    m.name,
    if (m.dosage != null) m.dosage!,
    if (m.description.isNotEmpty) m.description,
    if (m.note != null) m.note!,
  ].join('. ');
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Theme(
      data: AppTheme.build(UiDensity.elder),
      child: Builder(
        builder: (context) {
          final text = Theme.of(context).textTheme;
          final size = (MediaQuery.of(context).size.width - 2 * AppSpacing.lg).clamp(120.0, 320.0);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  m.photos.isEmpty ? NoMedPhoto(size: size) : LocalMedPhoto(path: m.photos.first, size: size),
                  if (m.photos.length > 1) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text('Ảnh bao bì', style: text.bodyLarge),
                    LocalMedPhoto(path: m.photos[1], size: size * 0.6),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(m.name, style: text.headlineSmall, textAlign: TextAlign.center),
                  Text('Uống lúc ${hhmm(slot.at)}${m.dosage == null ? '' : ' · ${m.dosage}'}', style: text.titleMedium),
                  if (m.description.isNotEmpty) Text(m.description, style: text.bodyLarge, textAlign: TextAlign.center),
                  if (m.note != null)
                    Text(
                      m.note!,
                      style: text.bodyLarge?.copyWith(color: AppColors.muted),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(72)),
                    onPressed: () => AlarmChannel.speak(speech),
                    icon: const Icon(Icons.volume_up, size: 32),
                    label: const Text('Nghe đọc'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Nếu nghi ngờ, hãy đối chiếu vỏ thuốc và hỏi dược sĩ, bác sĩ.',
                    style: text.bodyMedium?.copyWith(color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// The next dose: big, outlined in blue, with the pill photo. Tap for details and "Nghe đọc".
class _NextCard extends StatelessWidget {
  const _NextCard({required this.slot, required this.now});

  final DoseSlot slot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = slot.med;
    final due = slot.statusAt(now) == DoseStatus.due;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.primary, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _showDose(context, slot),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                due ? 'Đến giờ uống: ${hhmm(slot.at)}' : 'Tiếp theo: ${hhmm(slot.at)}',
                style: text.titleMedium?.copyWith(color: AppColors.primary, fontSize: 22),
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              Row(
                children: [
                  m.photos.isEmpty ? const NoMedPhoto(size: 96) : LocalMedPhoto(path: m.photos.first, size: 96),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: text.headlineSmall?.copyWith(fontSize: 30, height: 1.15)),
                        if (m.dosage != null) Text(m.dosage!, style: text.bodyLarge?.copyWith(fontSize: 22)),
                        if (m.description.isNotEmpty)
                          Text(m.description, style: text.bodyLarge?.copyWith(color: AppColors.muted, fontSize: 20)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dose whose alarm went quiet without an answer. The elder can still answer it here.
class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.minute, required this.slots, required this.onTaken, required this.onNotTaken});

  final DateTime minute;
  final List<DoseSlot> slots;
  final VoidCallback onTaken;
  final VoidCallback onNotTaken;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md + 4),
      decoration: BoxDecoration(
        color: AppColors.warnSoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warn, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_paused_outlined, color: AppColors.warn, size: 30),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Thuốc ${hhmm(minute)} chưa trả lời',
                  style: text.titleMedium?.copyWith(fontSize: 22, color: AppColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(slots.map((d) => [d.med.name, d.med.dosage].whereType<String>().join(' ')).join(', '), style: text.bodyLarge),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ok,
              foregroundColor: AppColors.onAccent,
              minimumSize: const Size.fromHeight(80),
              textStyle: text.titleMedium?.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            onPressed: onTaken,
            icon: const Icon(Icons.check, size: 32),
            label: const Text('ĐÃ UỐNG RỒI'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(64)),
            onPressed: onNotTaken,
            child: const Text('Chưa uống được'),
          ),
        ],
      ),
    );
  }
}

/// "07:30 · Đã uống thuốc" in green (or amber for "chưa uống được").
class _DoneRow extends StatelessWidget {
  const _DoneRow({required this.ok, required this.label, this.onTap});

  final bool ok;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = ok ? AppColors.ok : AppColors.warn;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      child: Material(
        color: ok ? AppColors.okSoft : AppColors.warnSoft,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Icon(ok ? Icons.check : Icons.priority_high, color: AppColors.onAccent, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(label, style: text.titleMedium?.copyWith(fontSize: 21))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One exercise of today; "Tôi đi tập đây" once it is time (or later), "Đã tập" after.
class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.slot, required this.now, required this.onGo});

  final ExerciseSlot slot;
  final DateTime now;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final st = slot.statusAt(now);
    final (label, icon, color, soft) = st == DoseStatus.taken
        ? ('Đã tập', Icons.check_circle, AppColors.ok, AppColors.okSoft)
        : st == DoseStatus.missed
        ? ('Chưa tập', Icons.error_outline, AppColors.warn, AppColors.warnSoft)
        : statusLook(st);
    final e = slot.exercise;
    return Card(
      color: soft,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.directions_walk, size: 56, color: AppColors.ok),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hhmm(slot.at),
                        style: text.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w800),
                      ),
                      Text(e.title, style: text.titleMedium),
                      if (e.durationMin != null) Text('${e.durationMin} phút', style: text.bodyLarge),
                      Row(
                        children: [
                          Icon(icon, color: color, size: 24),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              label == 'Đến giờ uống' ? 'Đến giờ tập' : label,
                              style: text.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (st == DoseStatus.due || st == DoseStatus.missed) ...[
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.ok, minimumSize: const Size.fromHeight(72)),
                onPressed: onGo,
                icon: const Icon(Icons.directions_walk, size: 32),
                label: const Text('TÔI ĐI TẬP ĐÂY'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
