import 'dart:async';

import 'package:flutter/material.dart';
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
/// from the copy saved on the phone (works offline). Ends only by an answer or a 10-minute snooze.
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({super.key});

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen> {
  List<int> _ids = const [];
  Timer? _poll;
  bool _busy = false;
  final _pages = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _loadIds();
    // A new alarm can join while this screen is open; pick it up without the elder doing anything.
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _loadIds());
  }

  Future<void> _loadIds() async {
    final ids = await AlarmChannel.ringingIds();
    if (!mounted || _busy) return;
    if (ids.isEmpty && _ids.isNotEmpty) {
      context.go('/'); // Stopped elsewhere (e.g. a caregiver marked it, Phase 6).
      return;
    }
    if (ids.join(',') != _ids.join(',')) setState(() => _ids = ids);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pages.dispose();
    super.dispose();
  }

  /// Doses still to answer, grouped by their minute (two alarms can be ringing together).
  Map<DateTime, List<ElderMed>> _due(ElderSchedule? s) {
    final out = <DateTime, List<ElderMed>>{};
    if (s == null) return out;
    final minutes = _ids.map(doseMinuteOf).whereType<DateTime>().toSet().toList()..sort();
    for (final minute in minutes) {
      final meds = [for (final m in s.medsAt(minute)) if (!s.logs.containsKey(doseKey(m.id, minute))) m];
      if (meds.isNotEmpty) out[minute] = meds;
    }
    return out;
  }

  Future<void> _answer({required bool taken, bool byVoice = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final due = _due(ref.read(elderScheduleProvider).value);
    await AlarmChannel.stopRinging();
    final outbox = ref.read(outboxProvider);
    final eventIds = <String>[
      for (final e in due.entries)
        await outbox.startDoseReport(
            minute: e.key, medicationIds: e.value.map((m) => m.id).toList(), taken: taken, byVoice: byVoice),
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
    if (_busy) return;
    setState(() => _busy = true);
    final s = ref.read(elderScheduleProvider).value;
    final ids = _ids;
    await AlarmChannel.stopRinging();
    final at = DateTime.now().add(const Duration(minutes: 10));
    for (final id in ids.isEmpty ? [-1] : ids) {
      final minute = id < 0 ? null : doseMinuteOf(id);
      final meds = (s == null || minute == null) ? const <ElderMed>[] : s.medsAt(minute);
      await AlarmChannel.schedule(
        id: id >= scheduleIdBase ? id - _snoozeOffset : (id >= 0 ? id : DateTime.now().millisecondsSinceEpoch ~/ 1000 % 1000000),
        at: at,
        title: 'Nhắc lại: ${titleFor(meds)}',
        speech: speechFor(s?.callName ?? '', meds),
      );
    }
    if (mounted) context.go('/');
  }

  void _onVoice(String words) {
    switch (classifyConfirm(words)) {
      case ConfirmIntent.taken:
        _answer(taken: true, byVoice: true);
      case ConfirmIntent.notTaken:
        _answer(taken: false, byVoice: true);
      case ConfirmIntent.snooze:
        _snooze();
      case ConfirmIntent.unknown:
        // Not sure what was said: record nothing, keep reminding (plan §9).
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa nghe rõ. Hãy bấm nút trên màn hình.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final due = _due(ref.watch(elderScheduleProvider).value);
    final cards = [for (final e in due.entries) for (final m in e.value) (e.key, m)];
    return Theme(
      data: AppTheme.build(UiDensity.elder),
      child: Builder(builder: (context) {
        final text = Theme.of(context).textTheme;
        final white = text.bodyLarge?.copyWith(color: Colors.white);
        return PopScope(
          canPop: false, // Back does not end the alarm; only an answer or a snooze does.
          child: Scaffold(
            backgroundColor: AppColors.primary,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Đến giờ uống thuốc',
                          textAlign: TextAlign.center, style: text.headlineMedium?.copyWith(color: Colors.white)),
                    ),
                    if (cards.length > 1)
                      Text('${cards.length} loại thuốc · đang xem ${_page + 1}/${cards.length}',
                          textAlign: TextAlign.center, style: white),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: cards.isEmpty
                          ? Center(child: Text('Uống thuốc theo lịch con dặn.', textAlign: TextAlign.center, style: white))
                          : PageView(
                              controller: _pages,
                              onPageChanged: (i) => setState(() => _page = i),
                              children: [for (final c in cards) _MedCard(minute: c.$1, med: c.$2)],
                            ),
                    ),
                    if (cards.length > 1)
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        IconButton(
                          tooltip: 'Thuốc trước',
                          color: Colors.white,
                          iconSize: 40,
                          onPressed: _page == 0 ? null : () => _pages.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          tooltip: 'Thuốc tiếp theo',
                          color: Colors.white,
                          iconSize: 40,
                          onPressed: _page >= cards.length - 1 ? null : () => _pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ]),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      key: const Key('confirmTaken'),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.white, foregroundColor: AppColors.ok, minimumSize: const Size.fromHeight(96)),
                      onPressed: _busy ? null : () => _answer(taken: true),
                      icon: const Icon(Icons.check_circle, size: 40),
                      label: Text(cards.length > 1 ? 'ĐÃ UỐNG HẾT RỒI' : 'ĐÃ UỐNG RỒI'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      key: const Key('notTaken'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 2),
                        minimumSize: const Size.fromHeight(72),
                      ),
                      onPressed: _busy ? null : () => _answer(taken: false),
                      icon: const Icon(Icons.block, size: 32),
                      label: const Text('KHÔNG UỐNG ĐƯỢC'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(0, 64)),
                          onPressed: _busy ? null : _snooze,
                          child: const Text('Nhắc lại sau 10 phút', textAlign: TextAlign.center),
                        ),
                      ),
                      VoiceButton(onHeard: _onVoice),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _MedCard extends StatelessWidget {
  const _MedCard({required this.minute, required this.med});

  final DateTime minute;
  final ElderMed med;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hhmm = '${minute.hour.toString().padLeft(2, '0')}:${minute.minute.toString().padLeft(2, '0')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(builder: (context, box) {
          final photo = (box.maxWidth * 0.6).clamp(120.0, 200.0);
          return SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Semantics(
                label: 'Ảnh thuốc ${med.name}',
                image: true,
                child: med.photos.isEmpty ? NoMedPhoto(size: photo) : LocalMedPhoto(path: med.photos.first, size: photo),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(med.name, style: text.headlineSmall, textAlign: TextAlign.center),
              if (med.dosage != null) Text(med.dosage!, style: text.titleMedium, textAlign: TextAlign.center),
              if (med.description.isNotEmpty) Text(med.description, style: text.bodyLarge, textAlign: TextAlign.center),
              if (med.note != null)
                Text(med.note!, style: text.bodyLarge?.copyWith(color: AppColors.muted), textAlign: TextAlign.center),
              Text('Giờ uống $hhmm', style: text.bodyLarge?.copyWith(color: AppColors.muted)),
            ]),
          );
        }),
      ),
    );
  }
}
