import 'dart:async';

import 'package:material_ui/material_ui.dart';
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

part 'elder_home_parts.dart';

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
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(elderScheduleProvider.notifier).refresh();
        ref.invalidate(readinessProvider);
      },
    );
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
    final ok = await confirm(
      context,
      title: 'Báo cho các con?',
      message: 'Các con sẽ nhận được tin là bạn đang thấy không khỏe.',
      action: 'Báo cho con',
    );
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Đã báo cho các con', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                UnwellHelp(groupId: _groupId),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Answer a dose from the home screen after its alarm went quiet ("Thuốc 11:30 chưa trả lời").
  Future<void> _answerLate(DateTime minute, List<DoseSlot> slots, {required bool taken}) async {
    final outbox = ref.read(outboxProvider);
    final id = await outbox.startDoseReport(minute: minute, medicationIds: [for (final d in slots) d.med.id], taken: taken);
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
      child: Builder(
        builder: (context) {
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
          final later = today
              .where((d) => d.statusAt(_now) == DoseStatus.upcoming && (next == null || d.at.isAfter(next.at)))
              .map((d) => d.at)
              .toSet()
              .toList();
          final answered = <DateTime, String>{};
          for (final d in today) {
            if (d.logStatus != null) {
              answered[d.at] = answered[d.at] == 'TAKEN' || d.logStatus == 'TAKEN' ? 'TAKEN' : d.logStatus!;
            }
          }
          final exercises = s == null
              ? const <ExerciseSlot>[]
              : s.exercisesOn(_now).where((e) => e.statusAt(_now) != DoseStatus.notApplicable).toList();
          final exercisesDone = exercises.where((e) => e.done).toList();
          final exercisesOpen = exercises.where((e) => !e.done && e.statusAt(_now) != DoseStatus.upcoming).toList();
          return Scaffold(
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => ref.read(elderScheduleProvider.notifier).refresh(),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
                        children: [
                          Text('Chào $name', style: text.bodyLarge?.copyWith(color: AppColors.muted, fontSize: 22)),
                          Semantics(
                            label:
                                'Bây giờ là ${_now.hour} giờ ${_now.minute} phút, ${_weekday[_now.weekday]} ngày ${_now.day} tháng ${_now.month}',
                            excludeSemantics: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hhmm(_now),
                                  style: text.displaySmall?.copyWith(
                                    fontSize: 56,
                                    height: 1.05,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                                Text(
                                  '${_weekday[_now.weekday]}, ${_now.day} tháng ${_now.month}',
                                  style: text.bodyLarge?.copyWith(color: AppColors.muted, fontSize: 22),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (ref.watch(sessionProvider).value?.expired ?? false)
                            _Banner(
                              icon: Icons.link_off,
                              color: AppColors.danger,
                              background: AppColors.dangerSoft,
                              text:
                                  'Máy cần được ghép lại. Báo thức vẫn chạy theo lịch đã lưu. '
                                  'Nhờ con tạo mã mới rồi bấm vào đây để nhập.',
                              onTap: () => context.push('/pair'),
                            ),
                          if (s != null && s.clockZoneDiffers(_now))
                            _Banner(
                              icon: Icons.schedule,
                              color: AppColors.danger,
                              background: AppColors.dangerSoft,
                              text: 'Giờ trên máy đang sai múi giờ, thuốc sẽ báo sai giờ. Nhờ con bấm vào đây để sửa.',
                              onTap: () => context.push('/readiness'),
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
                              text:
                                  'Đang không có mạng. Máy vẫn nhắc thuốc theo lịch đã lưu'
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
                          if (showNext) ...[_NextCard(slot: next, now: _now), const SizedBox(height: AppSpacing.lg)],
                          for (final e in answered.entries)
                            _DoneRow(
                              ok: e.value == 'TAKEN',
                              label:
                                  '${hhmm(e.key)} · ${e.value == 'TAKEN'
                                      ? 'Đã uống thuốc'
                                      : e.value == 'NOT_TAKEN'
                                      ? 'Chưa uống được'
                                      : 'Bỏ qua'}',
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
                            Text(
                              s.meds.isEmpty
                                  ? 'Chưa có thuốc nào. Khi con đặt lịch, thuốc sẽ hiện ở đây.'
                                  : 'Hôm nay không có thuốc.',
                              style: text.bodyLarge,
                            ),
                          if (s != null && today.isNotEmpty && next == null && waiting.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.sm),
                              child: Text('Xong thuốc hôm nay rồi ạ.', style: text.titleMedium?.copyWith(color: AppColors.ok)),
                            ),
                          const SizedBox(height: AppSpacing.xl),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(onPressed: () => context.push('/readiness'), child: const Text('Kiểm tra máy')),
                              TextButton(
                                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                                onPressed: () async {
                                  if (await confirm(
                                    context,
                                    title: 'Đăng xuất?',
                                    message: 'Máy sẽ thôi nhắc thuốc. Sẽ cần nhập lại mã của con.',
                                    action: 'Đăng xuất',
                                  )) {
                                    await ref.read(sessionProvider.notifier).logout(); // also clears schedule and alarms
                                  }
                                },
                                child: const Text('Đăng xuất'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            key: const Key('callChild'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(88),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                              textStyle: text.titleMedium?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
                            ),
                            onPressed: _groupId == null ? null : () => showCallSheet(context, _groupId!),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.call, size: 30),
                                SizedBox(height: 4),
                                Text('Gọi cho con', textAlign: TextAlign.center),
                              ],
                            ),
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
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.favorite_border, size: 30),
                                SizedBox(height: 4),
                                Text('Tôi thấy mệt', textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
