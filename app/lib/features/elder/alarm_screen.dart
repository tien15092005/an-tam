import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../domain/voice_intent.dart';
import '../../reminder/alarm_channel.dart';
import '../../reminder/elder_schedule.dart';
import '../../reminder/outbox.dart';
import '../../reminder/schedule_sync.dart';
import '../medications/med_photo.dart';
import 'voice_button.dart';

part 'alarm_cards.dart';

/// Snoozes of a schedule alarm live below the schedule range (so a re-sync never cancels them)
/// but still decode to the same minute.
const _snoozeOffset = 50000000;

DateTime? doseMinuteOf(int alarmId) =>
    minuteOfAlarmId(alarmId) ?? (alarmId >= _snoozeOffset ? minuteOfAlarmId(alarmId + _snoozeOffset) : null);

/// What the question screen needs: the reports started by the answer, and which answer it was.
class QuestionArgs {
  const QuestionArgs(this.eventIds, {required this.taken});
  final List<String> eventIds;
  final bool taken;
}

/// Full-screen alarm over the lock screen (plan §9): every medicine due, with photo and description,
/// from the copy saved on the phone (works offline). Ends by an answer or a 10-minute snooze; unanswered,
/// the phone goes quiet after 2 minutes and rings again twice, 10 minutes apart (AlarmService).
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({super.key});

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen> {
  List<int> _ids = const [];

  /// Which ring this is (1 at the dose time, up to [maxAlarmAttempts]); snoozing is not offered on the last.
  int _attempt = 1;
  Timer? _poll;
  Timer? _sync;
  bool _busy = false;
  final _pages = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _loadIds();
    // A new alarm can join while this screen is open; pick it up without the elder doing anything.
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _loadIds());
    // A caregiver may mark the dose for the elder (plan §9): when the phone is online it learns this
    // from the server and stops. Offline it simply keeps ringing until the elder answers.
    _sync = Timer.periodic(const Duration(seconds: 20), (_) => _checkMarkedByCaregiver());
  }

  Future<void> _checkMarkedByCaregiver() async {
    if (_busy || _ids.isEmpty) return;
    try {
      await ref.read(elderScheduleProvider.notifier).refresh();
    } catch (_) {
      return;
    }
    final s = ref.read(elderScheduleProvider).value;
    if (!mounted || _busy || s == null) return;
    final minutes = _ids.map(doseMinuteOf).whereType<DateTime>().toSet();
    final answered =
        minutes.isNotEmpty &&
        minutes.every((m) {
          final meds = s.medsAt(m);
          return meds.isNotEmpty && meds.every((x) => s.logs.containsKey(doseKey(x.id, m)));
        });
    if (!answered) return;
    setState(() => _busy = true);
    await AlarmChannel.stopRinging();
    await AlarmChannel.speak('Con đã ghi nhận ${s.callName} uống thuốc rồi ạ.');
    if (mounted) context.go('/');
  }

  Future<void> _loadIds() async {
    final ids = await AlarmChannel.ringingIds();
    final attempt = await AlarmChannel.ringingAttempt();
    if (!mounted || _busy) return;
    if (ids.isEmpty && _ids.isNotEmpty) {
      // Stopped elsewhere: a caregiver marked it, or nobody answered for 2 minutes and the phone went quiet.
      context.go('/');
      return;
    }
    if (ids.join(',') != _ids.join(',') || attempt != _attempt) {
      setState(() {
        _ids = ids;
        _attempt = attempt;
      });
    }
    _stopIfAlreadyAnswered();
  }

  /// A repeat ring for doses answered meanwhile (e.g. from the home screen while offline): stop at once.
  Future<void> _stopIfAlreadyAnswered() async {
    final s = ref.read(elderScheduleProvider).value;
    if (s == null || _ids.isEmpty || _busy) return;
    final minutes = _ids.map(doseMinuteOf).whereType<DateTime>().toSet();
    if (minutes.length != _ids.length) return; // an id without a dose minute: keep ringing to be safe
    if (_due(s).isNotEmpty || _exercisesDue(s).isNotEmpty) return;
    if (minutes.every((m) => s.medsAt(m).isEmpty && s.exercisesAt(m).isEmpty)) return; // schedule not loaded yet
    setState(() => _busy = true);
    await AlarmChannel.stopRinging();
    await AlarmChannel.answered([for (final m in minutes) alarmIdForMinute(m)]);
    if (mounted) context.go('/');
  }

  @override
  void dispose() {
    _poll?.cancel();
    _sync?.cancel();
    _pages.dispose();
    super.dispose();
  }

  /// Exercises at the ringing minutes that the elder has not gone to yet (Phase 7).
  List<(DateTime, ElderExercise)> _exercisesDue(ElderSchedule? s) {
    if (s == null) return const [];
    final minutes = _ids.map(doseMinuteOf).whereType<DateTime>().toSet().toList()..sort();
    return [
      for (final m in minutes)
        for (final e in s.exercisesAt(m))
          if (!s.exercisesDone.contains(exerciseKey(e.id, m))) (m, e),
    ];
  }

  /// "TÔI ĐI TẬP ĐÂY" for an exercise-only alarm: record, stop, wish them well.
  Future<void> _goExercise({bool byVoice = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final s = ref.read(elderScheduleProvider).value;
    final due = _exercisesDue(s);
    await AlarmChannel.stopRinging();
    final outbox = ref.read(outboxProvider);
    for (final (minute, e) in due) {
      await outbox.reportExercise(exerciseId: e.id, day: minute, byVoice: byVoice);
    }
    await ref.read(elderScheduleProvider.notifier).reloadLocal();
    final who = s?.callName ?? '';
    await AlarmChannel.speak('Chúc ${who.isEmpty ? '' : '$who '}tập vui ạ.');
    if (mounted) context.go('/');
  }

  /// Exercise card button when medicines ring at the same minute: records it without stopping the alarm.
  Future<void> _markExercise(DateTime minute, ElderExercise e) async {
    await ref.read(outboxProvider).reportExercise(exerciseId: e.id, day: minute);
    await ref.read(elderScheduleProvider.notifier).reloadLocal();
  }

  /// Doses still to answer, grouped by their minute (two alarms can be ringing together).
  Map<DateTime, List<ElderMed>> _due(ElderSchedule? s) {
    final out = <DateTime, List<ElderMed>>{};
    if (s == null) return out;
    final minutes = _ids.map(doseMinuteOf).whereType<DateTime>().toSet().toList()..sort();
    for (final minute in minutes) {
      final meds = [
        for (final m in s.medsAt(minute))
          if (!s.logs.containsKey(doseKey(m.id, minute))) m,
      ];
      if (meds.isNotEmpty) out[minute] = meds;
    }
    return out;
  }

  Future<void> _answer({required bool taken, bool byVoice = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final due = _due(ref.read(elderScheduleProvider).value);
    await AlarmChannel.stopRinging();
    await AlarmChannel.answered([for (final m in _ids.map(doseMinuteOf).whereType<DateTime>().toSet()) alarmIdForMinute(m)]);
    final outbox = ref.read(outboxProvider);
    final eventIds = <String>[
      for (final e in due.entries)
        await outbox.startDoseReport(
          minute: e.key,
          medicationIds: e.value.map((m) => m.id).toList(),
          taken: taken,
          byVoice: byVoice,
        ),
    ];
    await ref.read(elderScheduleProvider.notifier).reloadLocal();
    if (!mounted) return;
    if (eventIds.isEmpty) {
      context.go('/');
    } else {
      context.go('/alarm/question', extra: QuestionArgs(eventIds, taken: taken));
    }
  }

  Future<void> _snooze() async {
    if (_busy || _attempt >= maxAlarmAttempts) return;
    setState(() => _busy = true);
    final s = ref.read(elderScheduleProvider).value;
    final ids = _ids;
    await AlarmChannel.stopRinging();
    final at = DateTime.now().add(const Duration(minutes: 10));
    for (final id in ids.isEmpty ? [-1] : ids) {
      final minute = id < 0 ? null : doseMinuteOf(id);
      final meds = (s == null || minute == null) ? const <ElderMed>[] : s.medsAt(minute);
      final exercises = (s == null || minute == null) ? const <ElderExercise>[] : s.exercisesAt(minute);
      final onlyExercise = meds.isEmpty && exercises.isNotEmpty;
      await AlarmChannel.schedule(
        id: id >= scheduleIdBase ? id - _snoozeOffset : (id >= 0 ? id : DateTime.now().millisecondsSinceEpoch ~/ 1000 % 1000000),
        at: at,
        title: onlyExercise ? 'Nhắc lại: tập thể dục' : 'Nhắc lại: ${titleFor(meds)}',
        speech: onlyExercise ? exerciseSpeechFor(s?.callName ?? '', exercises) : speechFor(s?.callName ?? '', meds),
        attempt: _attempt + 1,
      );
    }
    if (mounted) context.go('/');
  }

  void _onVoice(String words) {
    final onlyExercise =
        _due(ref.read(elderScheduleProvider).value).isEmpty && _exercisesDue(ref.read(elderScheduleProvider).value).isNotEmpty;
    switch (classifyConfirm(words)) {
      case ConfirmIntent.taken when onlyExercise:
        _goExercise(byVoice: true);
      case ConfirmIntent.notTaken when onlyExercise:
        // Not a medicine: nothing to record; keep reminding until "đi tập" or a snooze.
        break;
      case ConfirmIntent.taken:
        _answer(taken: true, byVoice: true);
      case ConfirmIntent.notTaken:
        _answer(taken: false, byVoice: true);
      case ConfirmIntent.snooze when _attempt < maxAlarmAttempts:
        _snooze();
      case ConfirmIntent.snooze:
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đây là lần nhắc cuối. Hãy bấm Đã uống hoặc Chưa uống được.')));
      case ConfirmIntent.unknown:
        // Not sure what was said: record nothing, keep reminding (plan §9).
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa nghe rõ. Hãy bấm nút trên màn hình.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(elderScheduleProvider).value;
    final due = _due(schedule);
    final medCards = [
      for (final e in due.entries)
        for (final m in e.value) (e.key, m),
    ];
    final exercises = _exercisesDue(schedule);
    final onlyExercise = medCards.isEmpty && exercises.isNotEmpty;
    final cards = <Widget>[
      for (final c in medCards) _MedCard(minute: c.$1, med: c.$2),
      for (final (minute, e) in exercises)
        _ExerciseCard(minute: minute, exercise: e, onGo: onlyExercise || _busy ? null : () => _markExercise(minute, e)),
    ];
    final name = schedule?.callName ?? '';
    final lastRing = _attempt >= maxAlarmAttempts;
    return Theme(
      data: AppTheme.build(UiDensity.elder),
      child: Builder(
        builder: (context) {
          final text = Theme.of(context).textTheme;
          final onBand = text.bodyLarge?.copyWith(color: AppColors.onAccent);
          return PopScope(
            canPop: false, // Back does not end the alarm; only an answer or a snooze does.
            child: Scaffold(
              backgroundColor: AppColors.surface,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: AppColors.primary,
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      MediaQuery.paddingOf(context).top + AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.volume_up, color: AppColors.onAccent, size: 24),
                            const SizedBox(width: AppSpacing.sm),
                            Text(_attempt > 1 ? 'Nhắc lại lần $_attempt' : 'Đang đọc to...', style: onBand),
                          ],
                        ),
                        Semantics(
                          header: true,
                          child: Text(
                            '${name.isEmpty ? '' : '$name ơi, '}${onlyExercise ? 'đến giờ tập thể dục' : 'đến giờ uống thuốc'}',
                            style: text.headlineSmall?.copyWith(color: AppColors.onAccent, height: 1.15),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                      child: Column(
                        children: [
                          Expanded(
                            child: cards.isEmpty
                                ? Center(
                                    child: Text(
                                      'Uống thuốc theo lịch con dặn.',
                                      textAlign: TextAlign.center,
                                      style: text.titleMedium,
                                    ),
                                  )
                                : PageView(controller: _pages, onPageChanged: (i) => setState(() => _page = i), children: cards),
                          ),
                          if (cards.length > 1)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: 'Thuốc trước',
                                  iconSize: 40,
                                  onPressed: _page == 0
                                      ? null
                                      : () => _pages.previousPage(
                                          duration: const Duration(milliseconds: 250),
                                          curve: Curves.easeOut,
                                        ),
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Text(
                                  '${_page + 1} trong ${cards.length}',
                                  style: text.bodyLarge?.copyWith(color: AppColors.muted),
                                ),
                                IconButton(
                                  tooltip: 'Thuốc tiếp theo',
                                  iconSize: 40,
                                  onPressed: _page >= cards.length - 1
                                      ? null
                                      : () => _pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (onlyExercise)
                            FilledButton.icon(
                              key: const Key('goExercise'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.ok,
                                foregroundColor: AppColors.onAccent,
                                minimumSize: const Size.fromHeight(100),
                                textStyle: text.headlineSmall?.copyWith(fontSize: 28),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                              ),
                              onPressed: _busy ? null : _goExercise,
                              icon: const Icon(Icons.directions_walk, size: 40),
                              label: const Text('TÔI ĐI TẬP ĐÂY'),
                            )
                          else ...[
                            FilledButton.icon(
                              key: const Key('confirmTaken'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.ok,
                                foregroundColor: AppColors.onAccent,
                                minimumSize: const Size.fromHeight(100),
                                textStyle: text.headlineSmall?.copyWith(fontSize: 28),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                              ),
                              onPressed: _busy ? null : () => _answer(taken: true),
                              icon: const Icon(Icons.check, size: 40),
                              label: Text(cards.length > 1 ? 'ĐÃ UỐNG HẾT' : 'ĐÃ UỐNG RỒI'),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    key: const Key('notTaken'),
                                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(76)),
                                    onPressed: _busy ? null : () => _answer(taken: false),
                                    child: const Text('Chưa uống được', textAlign: TextAlign.center),
                                  ),
                                ),
                                if (!lastRing) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: OutlinedButton(
                                      key: const Key('snooze'),
                                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(76)),
                                      onPressed: _busy ? null : _snooze,
                                      child: const Text('Nhắc lại sau 10 phút', textAlign: TextAlign.center),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                          if (lastRing)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.sm),
                              child: Text(
                                'Đây là lần nhắc cuối. Chưa trả lời thì các con sẽ được báo.',
                                textAlign: TextAlign.center,
                                style: text.bodyMedium,
                              ),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          Center(
                            child: VoiceButton(onHeard: _onVoice, foreground: AppColors.primary),
                          ),
                        ],
                      ),
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
