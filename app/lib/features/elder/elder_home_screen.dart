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
import 'alarm_screen.dart' show QuestionArgs;
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
    // Fallback when no push arrives: re-sync every few hours even if the app is never opened (plan §9).
    AlarmChannel.setBackgroundSync(true);
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

  /// Answer a dose from the home screen after its alarm went quiet ("Thuốc 11:30 chưa trả lời").
  Future<void> _answerLate(DateTime minute, List<DoseSlot> slots, {required bool taken}) async {
    final outbox = ref.read(outboxProvider);
    final id = await outbox.startDoseReport(
      minute: minute,
      medicationIds: [for (final d in slots) d.med.id],
      taken: taken,
    );
    await AlarmChannel.answered([alarmIdForMinute(minute)]);
    await ref.read(elderScheduleProvider.notifier).reloadLocal();
    if (mounted) context.go('/alarm/question', extra: QuestionArgs([id], taken: taken));
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
        final waiting = <DateTime, List<DoseSlot>>{};
        for (final d in s == null ? const <DoseSlot>[] : unansweredDoses(s, _now)) {
          waiting.putIfAbsent(d.at, () => []).add(d);
        }
        final next = s?.nextDose(_now);
        final showNext = next != null && !waiting.containsKey(next.at);
        final later = today.where((d) => d.statusAt(_now) == DoseStatus.upcoming && (next == null || d.at.isAfter(next.at)))
            .map((d) => d.at)
            .toSet()
            .toList();
        final answered = <DateTime, String>{};
        for (final d in today) {
          if (d.logStatus != null) answered[d.at] = answered[d.at] == 'TAKEN' || d.logStatus == 'TAKEN' ? 'TAKEN' : d.logStatus!;
        }
        final exercises = s == null
            ? const <ExerciseSlot>[]
            : s.exercisesOn(_now).where((e) => e.statusAt(_now) != DoseStatus.notApplicable).toList();
        final exercisesDone = exercises.where((e) => e.done).toList();
        final exercisesOpen = exercises.where((e) => !e.done && e.statusAt(_now) != DoseStatus.upcoming).toList();
        return Scaffold(
          body: SafeArea(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.read(elderScheduleProvider.notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
                    children: [
                      Text('Chào $name', style: text.bodyLarge?.copyWith(color: AppColors.muted, fontSize: 22)),
                      Semantics(
                        label: 'Bây giờ là ${_now.hour} giờ ${_now.minute} phút, ${_weekday[_now.weekday]} ngày ${_now.day} tháng ${_now.month}',
                        excludeSemantics: true,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(hhmm(_now),
                              style: text.displaySmall?.copyWith(
                                  fontSize: 56, height: 1.05, fontFeatures: const [FontFeature.tabularFigures()])),
                          Text('${_weekday[_now.weekday]}, ${_now.day} tháng ${_now.month}',
                              style: text.bodyLarge?.copyWith(color: AppColors.muted, fontSize: 22)),
                        ]),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (ref.watch(sessionProvider).value?.expired ?? false)
                        _Banner(
                          icon: Icons.link_off,
                          color: AppColors.danger,
                          background: AppColors.dangerSoft,
                          text: 'Máy cần được ghép lại. Báo thức vẫn chạy theo lịch đã lưu. '
                              'Nhờ con tạo mã mới rồi bấm vào đây để nhập.',
                          onTap: () => context.push('/pair'),
                        ),
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
                      for (final e in waiting.entries)
                        _WaitingCard(
                          minute: e.key,
                          slots: e.value,
                          onTaken: () => _answerLate(e.key, e.value, taken: true),
                          onNotTaken: () => _answerLate(e.key, e.value, taken: false),
                        ),
                      if (showNext) ...[
                        _NextCard(slot: next, now: _now),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      for (final e in answered.entries)
                        _DoneRow(
                          ok: e.value == 'TAKEN',
                          label: '${hhmm(e.key)} · ${e.value == 'TAKEN' ? 'Đã uống thuốc' : e.value == 'NOT_TAKEN' ? 'Chưa uống được' : 'Bỏ qua'}',
                          onTap: () => _showDose(context, today.firstWhere((d) => d.at == e.key)),
                        ),
                      for (final e in exercisesDone) _DoneRow(ok: true, label: '${hhmm(e.at)} · Đã đi tập'),
                      for (final e in exercisesOpen)
                        _ExerciseRow(
                          slot: e,
                          now: _now,
                          onGo: () async {
                            await ref.read(outboxProvider).reportExercise(exerciseId: e.exercise.id, day: e.at);
                            await ref.read(elderScheduleProvider.notifier).reloadLocal();
                          },
                        ),
                      if (later.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.xs, top: AppSpacing.xs),
                          child: Text(
                            later.length == 1
                                ? 'Còn 1 lần nữa lúc ${hhmm(later.first)}'
                                : 'Còn ${later.length} lần nữa: ${later.map(hhmm).join(', ')}',
                            style: text.bodyLarge?.copyWith(color: AppColors.muted),
                          ),
                        ),
                      if (s != null && today.isEmpty && exercises.isEmpty)
                        Text(s.meds.isEmpty ? 'Chưa có thuốc nào. Khi con đặt lịch, thuốc sẽ hiện ở đây.' : 'Hôm nay không có thuốc.',
                            style: text.bodyLarge),
                      if (s != null && today.isNotEmpty && next == null && waiting.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text('Xong thuốc hôm nay rồi ạ.', style: text.titleMedium?.copyWith(color: AppColors.ok)),
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        TextButton(onPressed: () => context.push('/readiness'), child: const Text('Kiểm tra máy')),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                          onPressed: () async {
                            if (await confirm(context,
                                title: 'Đăng xuất?', message: 'Máy sẽ thôi nhắc thuốc. Sẽ cần nhập lại mã của con.', action: 'Đăng xuất')) {
                              await ref.read(sessionProvider.notifier).logout(); // also clears schedule and alarms
                            }
                          },
                          child: const Text('Đăng xuất'),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                child: Row(children: [
                  Expanded(
                    child: FilledButton(
                      key: const Key('callChild'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(88),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        textStyle: text.titleMedium?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      onPressed: _groupId == null ? null : () => showCallSheet(context, _groupId!),
                      child: const Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.call, size: 30),
                        SizedBox(height: 4),
                        Text('Gọi cho con', textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('unwell'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: BorderSide(color: AppColors.danger, width: 2.5),
                        minimumSize: const Size.fromHeight(88),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        textStyle: text.titleMedium?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      onPressed: _unwell,
                      child: const Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.favorite_border, size: 30),
                        SizedBox(height: 4),
                        Text('Tôi thấy mệt', textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                ]),
              ),
            ]),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(due ? 'Đến giờ uống: ${hhmm(slot.at)}' : 'Tiếp theo: ${hhmm(slot.at)}',
                style: text.titleMedium?.copyWith(color: AppColors.primary, fontSize: 22)),
            const SizedBox(height: AppSpacing.sm + 4),
            Row(children: [
              m.photos.isEmpty ? const NoMedPhoto(size: 96) : LocalMedPhoto(path: m.photos.first, size: 96),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.name, style: text.headlineSmall?.copyWith(fontSize: 30, height: 1.15)),
                  if (m.dosage != null) Text(m.dosage!, style: text.bodyLarge?.copyWith(fontSize: 22)),
                  if (m.description.isNotEmpty)
                    Text(m.description, style: text.bodyLarge?.copyWith(color: AppColors.muted, fontSize: 20)),
                ]),
              ),
            ]),
          ]),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.notifications_paused_outlined, color: AppColors.warn, size: 30),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Thuốc ${hhmm(minute)} chưa trả lời',
                style: text.titleMedium?.copyWith(fontSize: 22, color: AppColors.ink)),
          ),
        ]),
        const SizedBox(height: AppSpacing.xs),
        Text(slots.map((d) => [d.med.name, d.med.dosage].whereType<String>().join(' ')).join(', '),
            style: text.bodyLarge),
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
      ]),
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
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(ok ? Icons.check : Icons.priority_high, color: AppColors.onAccent, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(label, style: text.titleMedium?.copyWith(fontSize: 21))),
              ]),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.directions_walk, size: 56, color: AppColors.ok),
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
