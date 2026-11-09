import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../domain/dose_status.dart';
import '../../reminder/alarm_channel.dart';
import '../../reminder/elder_schedule.dart';
import '../../reminder/outbox.dart';
import '../../reminder/schedule_sync.dart';
import '../auth/session.dart';
import '../groups/code_dialog.dart';
import '../groups/groups_api.dart';
import '../medications/med_photo.dart';
import 'call_children.dart';
import 'readiness_screen.dart';

String hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

const _weekday = {1: 'Thứ Hai', 2: 'Thứ Ba', 3: 'Thứ Tư', 4: 'Thứ Năm', 5: 'Thứ Sáu', 6: 'Thứ Bảy', 7: 'Chủ Nhật'};

/// Status always as icon + words + colour (plan §9), never colour alone.
(String, IconData, Color, Color) statusLook(DoseStatus s) => switch (s) {
      DoseStatus.taken => ('Đã uống', Icons.check_circle, AppColors.ok, AppColors.okSoft),
      DoseStatus.notTaken => ('Không uống được', Icons.block, AppColors.warn, AppColors.warnSoft),
      DoseStatus.skipped => ('Bỏ qua', Icons.remove_circle_outline, AppColors.muted, AppColors.surface),
      DoseStatus.due => ('Đến giờ uống', Icons.alarm, AppColors.primary, AppColors.primarySoft),
      DoseStatus.missed => ('Chưa xác nhận', Icons.error_outline, AppColors.danger, AppColors.dangerSoft),
      _ => ('Sắp tới', Icons.schedule, AppColors.navy, AppColors.surface),
    };

/// Elder home (plan §9): greeting, clock, the next medicine with its photo, today's list, and two
/// big buttons: call a child, "I feel unwell". Everything reads from the phone, so it works offline.
class ElderHomeScreen extends ConsumerStatefulWidget {
  const ElderHomeScreen({super.key, required this.me});

  final Me me;

  @override
  ConsumerState<ElderHomeScreen> createState() => _ElderHomeScreenState();
}

class _ElderHomeScreenState extends ConsumerState<ElderHomeScreen> {
  late final AppLifecycleListener _lifecycle;
  Timer? _tick;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Fresh schedule whenever the home screen appears (e.g. right after pairing), not only on resume.
    Future.microtask(() => ref.read(elderScheduleProvider.notifier).refresh());
    _lifecycle = AppLifecycleListener(onResume: () {
      ref.read(elderScheduleProvider.notifier).refresh();
      ref.invalidate(readinessProvider);
    });
    // Clock and statuses move on by themselves; the queue retries while the app is open.
    _tick = Timer.periodic(const Duration(seconds: 30), (t) {
      setState(() => _now = DateTime.now());
      if (t.tick % 2 == 0) ref.read(outboxProvider).flush();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _tick?.cancel();
    super.dispose();
  }

  int? get _groupId => widget.me.groups.isEmpty ? null : widget.me.groups.first.id;

  Future<void> _unwell() async {
    final ok = await confirm(context,
        title: 'Báo cho các con?', message: 'Các con sẽ nhận được tin là bạn đang thấy không khỏe.', action: 'Báo cho con');
    if (!ok) return;
    await ref.read(outboxProvider).raiseAlert(IssueKind.unwell);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Theme(
        data: AppTheme.build(UiDensity.elder),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Đã báo cho các con', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              UnwellHelp(groupId: _groupId),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(elderScheduleProvider);
    final readiness = ref.watch(readinessProvider).value;
    return Theme(
      data: AppTheme.build(UiDensity.elder),
      child: Builder(builder: (context) {
        final text = Theme.of(context).textTheme;
        final s = schedule.value;
        final name = (s?.callName.isNotEmpty ?? false) ? s!.callName : widget.me.displayName;
        final today = s == null
            ? const <DoseSlot>[]
            : s.dosesOn(_now).where((d) => d.statusAt(_now) != DoseStatus.notApplicable).toList();
        final next = s?.nextDose(_now);
        final exercises = s == null
            ? const <ExerciseSlot>[]
            : s.exercisesOn(_now).where((e) => e.statusAt(_now) != DoseStatus.notApplicable).toList();
        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => ref.read(elderScheduleProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text('Xin chào, $name', style: text.titleLarge),
                  Semantics(
                    label: 'Bây giờ là ${_now.hour} giờ ${_now.minute} phút, ${_weekday[_now.weekday]} ngày ${_now.day} tháng ${_now.month}',
                    excludeSemantics: true,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(hhmm(_now), style: text.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(width: AppSpacing.md),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text('${_weekday[_now.weekday]}, ${_now.day}/${_now.month}', style: text.bodyLarge),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (readiness != null && !readiness.alarmsReady)
                    _Banner(
                      icon: Icons.warning_amber,
                      color: AppColors.warn,
                      background: AppColors.warnSoft,
                      text: 'Máy chưa sẵn sàng báo thức. Nhờ con bấm vào đây để kiểm tra.',
                      onTap: () => context.push('/readiness'),
                    ),
                  if (s?.offline == true)
                    _Banner(
                      icon: Icons.wifi_off,
                      color: AppColors.warn,
                      background: AppColors.warnSoft,
                      text: 'Đang không có mạng. Máy vẫn nhắc thuốc theo lịch đã lưu'
                          '${s?.lastSynced == null ? '' : ' lúc ${hhmm(s!.lastSynced!)}'}.',
                    ),
                  if (schedule.isLoading && s == null) const LinearProgressIndicator(),
                  if (schedule.hasError && s == null) Text(describeNetworkError(schedule.error!), style: text.bodyLarge),
                  if (next != null) ...[
                    Text('Sắp tới', style: text.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    _NextCard(slot: next, now: _now),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('callChild'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.navy, minimumSize: const Size.fromHeight(88)),
                        onPressed: _groupId == null ? null : () => showCallSheet(context, _groupId!),
                        icon: const Icon(Icons.phone, size: 32),
                        label: const Text('Gọi cho con', textAlign: TextAlign.center),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('unwell'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger, width: 2),
                          minimumSize: const Size.fromHeight(88),
                        ),
                        onPressed: _unwell,
                        icon: const Icon(Icons.sick, size: 32),
                        label: const Text('Tôi thấy không khỏe', textAlign: TextAlign.center),
                      ),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(header: true, child: Text('Thuốc hôm nay', style: text.titleLarge)),
                  const SizedBox(height: AppSpacing.sm),
                  if (s != null && today.isEmpty)
                    Text(s.meds.isEmpty ? 'Chưa có thuốc nào. Khi con đặt lịch, thuốc sẽ hiện ở đây.' : 'Hôm nay không có thuốc.',
                        style: text.bodyLarge),
                  for (final d in today) _DoseCard(slot: d, now: _now),
                  if (exercises.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Semantics(header: true, child: Text('Tập thể dục hôm nay', style: text.titleLarge)),
                    const SizedBox(height: AppSpacing.sm),
                    for (final e in exercises)
                      _ExerciseRow(
                        slot: e,
                        now: _now,
                        onGo: () async {
                          await ref.read(outboxProvider).reportExercise(exerciseId: e.exercise.id, day: e.at);
                          await ref.read(elderScheduleProvider.notifier).reloadLocal();
                        },
                      ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  TextButton.icon(
                    onPressed: () => context.push('/readiness'),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Kiểm tra máy'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (await confirm(context,
                          title: 'Đăng xuất?', message: 'Máy sẽ thôi nhắc thuốc. Sẽ cần nhập lại mã của con.', action: 'Đăng xuất')) {
                        await ref.read(sessionProvider.notifier).logout(); // also clears schedule and alarms
                      }
                    },
                    child: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

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
            child: Row(children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
              if (onTap != null) Icon(Icons.chevron_right, color: color),
            ]),
          ),
        ),
      );
}

void _showDose(BuildContext context, DoseSlot slot) {
  final m = slot.med;
  final speech = [m.name, if (m.dosage != null) m.dosage!, if (m.description.isNotEmpty) m.description, if (m.note != null) m.note!]
      .join('. ');
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Theme(
      data: AppTheme.build(UiDensity.elder),
      child: Builder(builder: (context) {
        final text = Theme.of(context).textTheme;
        final size = (MediaQuery.of(context).size.width - 2 * AppSpacing.lg).clamp(120.0, 320.0);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
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
              if (m.note != null) Text(m.note!, style: text.bodyLarge?.copyWith(color: AppColors.muted), textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(72)),
                onPressed: () => AlarmChannel.speak(speech),
                icon: const Icon(Icons.volume_up, size: 32),
                label: const Text('Nghe đọc'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Nếu nghi ngờ, hãy đối chiếu vỏ thuốc và hỏi dược sĩ, bác sĩ.',
                  style: text.bodyMedium?.copyWith(color: AppColors.muted), textAlign: TextAlign.center),
            ]),
          ),
        );
      }),
    ),
  );
}

class _NextCard extends StatelessWidget {
  const _NextCard({required this.slot, required this.now});

  final DoseSlot slot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = slot.med;
    final (label, icon, color, soft) = statusLook(slot.statusAt(now));
    return Card(
      color: soft == AppColors.surface ? AppColors.navySoft : soft,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _showDose(context, slot),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: AppSpacing.sm),
              Text('${hhmm(slot.at)} · $label', style: text.titleMedium?.copyWith(color: color)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              m.photos.isEmpty ? const NoMedPhoto(size: 120) : LocalMedPhoto(path: m.photos.first, size: 120),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.name, style: text.titleLarge),
                  if (m.dosage != null) Text(m.dosage!, style: text.bodyLarge),
                  if (m.description.isNotEmpty) Text(m.description, style: text.bodyLarge?.copyWith(color: AppColors.muted)),
                ]),
              ),
            ]),
          ]),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.directions_walk, size: 56, color: AppColors.ok),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hhmm(slot.at), style: text.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w800)),
                Text(e.title, style: text.titleMedium),
                if (e.durationMin != null) Text('${e.durationMin} phút', style: text.bodyLarge),
                Row(children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(child: Text(label == 'Đến giờ uống' ? 'Đến giờ tập' : label,
                      style: text.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w700))),
                ]),
              ]),
            ),
          ]),
          if (st == DoseStatus.due || st == DoseStatus.missed) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.ok, minimumSize: const Size.fromHeight(72)),
              onPressed: onGo,
              icon: const Icon(Icons.directions_walk, size: 32),
              label: const Text('TÔI ĐI TẬP ĐÂY'),
            ),
          ],
        ]),
      ),
    );
  }
}

class _DoseCard extends StatelessWidget {
  const _DoseCard({required this.slot, required this.now});

  final DoseSlot slot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = slot.med;
    final (label, icon, color, soft) = statusLook(slot.statusAt(now));
    return Card(
      color: soft,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _showDose(context, slot),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            m.photos.isEmpty ? const NoMedPhoto(size: 80) : LocalMedPhoto(path: m.photos.first, size: 80),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hhmm(slot.at), style: text.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w800)),
                Text(m.name, style: text.titleMedium),
                if (m.dosage != null) Text(m.dosage!, style: text.bodyLarge),
                Row(children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(child: Text(label, style: text.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w700))),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
