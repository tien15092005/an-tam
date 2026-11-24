import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../domain/voice_intent.dart';
import '../../reminder/alarm_channel.dart';
import '../../reminder/outbox.dart';
import '../../reminder/schedule_sync.dart';
import '../groups/groups_api.dart';
import 'alarm_screen.dart' show QuestionArgs;
import 'call_children.dart';
import 'voice_button.dart';

/// After ĐÃ UỐNG RỒI / KHÔNG UỐNG ĐƯỢC: "có gặp vấn đề gì không?" (plan §9). The question is read up
/// to 3 times in 2 minutes; no answer is recorded as NO_RESPONSE and a confirmed dose stays confirmed.
class IssueQuestionScreen extends ConsumerStatefulWidget {
  const IssueQuestionScreen({super.key, required this.args});

  final QuestionArgs args;

  @override
  ConsumerState<IssueQuestionScreen> createState() => _IssueQuestionScreenState();
}

class _IssueQuestionScreenState extends ConsumerState<IssueQuestionScreen> {
  final List<Timer> _timers = [];
  bool _answered = false;
  IssueKind? _issue;

  String get _question {
    final name = ref.read(elderScheduleProvider).value?.callName ?? '';
    final who = name.isEmpty ? '' : '$name ';
    return widget.args.taken
        ? '${who}có gặp vấn đề gì không ạ? Không có gì thì bấm nút màu xanh.'
        : '${who}không uống được vì sao ạ? Bấm vào lý do.';
  }

  @override
  void initState() {
    super.initState();
    for (final s in const [0, 40, 80]) {
      _timers.add(Timer(Duration(seconds: s), () {
        if (!_answered) AlarmChannel.speak(_question).catchError((_) {});
      }));
    }
    _timers.add(Timer(Outbox.questionTimeout, () => _finish(null, noResponse: true)));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  Future<void> _finish(IssueKind? issue, {bool noResponse = false}) async {
    if (_answered) return;
    setState(() {
      _answered = true;
      _issue = issue;
    });
    for (final t in _timers) {
      t.cancel();
    }
    AlarmChannel.stopSpeaking().catchError((_) {});
    final outbox = ref.read(outboxProvider);
    for (final id in widget.args.eventIds) {
      await outbox.finishDoseReport(id, issue: issue, noResponse: noResponse);
    }
    if (noResponse) {
      if (mounted) context.go('/');
      return;
    }
    final thanks = issue == null ? 'Cảm ơn ạ.' : 'Đã báo cho các con rồi ạ.';
    AlarmChannel.speak(thanks).catchError((_) {});
    // Simple answers return home by themselves; for "unwell" or "other" the call buttons stay up.
    if (issue != IssueKind.unwell && issue != IssueKind.otherIssue) {
      _timers.add(Timer(const Duration(seconds: 6), () {
        if (mounted) context.go('/');
      }));
    }
  }

  void _onVoice(String words) {
    final i = classifyIssue(words);
    final map = {
      IssueIntent.lost: IssueKind.lostMedicine,
      IssueIntent.outOf: IssueKind.outOfMedicine,
      IssueIntent.unsure: IssueKind.unsurePill,
      IssueIntent.unwell: IssueKind.unwell,
      IssueIntent.other: IssueKind.otherIssue,
    };
    if (i == IssueIntent.none && widget.args.taken) {
      _finish(null);
    } else if (map.containsKey(i)) {
      _finish(map[i]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa nghe rõ. Hãy bấm vào câu trả lời.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupId = ref.watch(meProvider).value?.groups.firstOrNull?.id;
    return Theme(
      data: AppTheme.build(UiDensity.elder),
      child: Builder(builder: (context) {
        final text = Theme.of(context).textTheme;
        return PopScope(
          canPop: false,
          child: Scaffold(
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: _answered ? _after(context, text, groupId) : _ask(context, text),
              ),
            ),
          ),
        );
      }),
    );
  }

  List<Widget> _ask(BuildContext context, TextTheme text) {
    final name = ref.read(elderScheduleProvider).value?.callName ?? '';
    final who = name.isEmpty ? '' : '${name.split(' ').first} ';
    Widget tile(IssueKind kind, IconData icon, String label) {
      final danger = kind == IssueKind.unwell;
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(120),
          padding: const EdgeInsets.all(AppSpacing.sm),
          foregroundColor: danger ? AppColors.danger : AppColors.ink,
          side: BorderSide(color: danger ? AppColors.danger : AppColors.line, width: danger ? 2.5 : 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        onPressed: () => _finish(kind),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 34, color: danger ? AppColors.danger : AppColors.warn),
          const SizedBox(height: AppSpacing.sm),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: danger ? FontWeight.w700 : FontWeight.w600)),
        ]),
      );
    }

    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.args.taken ? AppColors.okSoft : AppColors.warnSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.args.taken ? Icons.check : Icons.info_outline,
                color: widget.args.taken ? AppColors.ok : AppColors.warn, size: 24),
            const SizedBox(width: 6),
            Text(widget.args.taken ? 'Đã ghi: đã uống' : 'Đã ghi: chưa uống được',
                style: text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600, color: widget.args.taken ? AppColors.ok : AppColors.warn)),
          ]),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Semantics(
        header: true,
        child: Text(widget.args.taken ? '${who}có gặp vấn đề gì không ạ?' : 'Vì sao ${who}chưa uống được ạ?',
            style: text.headlineMedium?.copyWith(fontSize: 34, height: 1.2)),
      ),
      const SizedBox(height: AppSpacing.md),
      if (widget.args.taken) ...[
        FilledButton(
          key: const Key('noProblem'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.ok,
            foregroundColor: AppColors.onAccent,
            minimumSize: const Size.fromHeight(100),
            textStyle: text.headlineSmall?.copyWith(fontSize: 30),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          ),
          onPressed: () => _finish(null),
          child: const Text('Không có gì'),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm + 4,
        crossAxisSpacing: AppSpacing.sm + 4,
        childAspectRatio: 1.3,
        children: [
          tile(IssueKind.lostMedicine, Icons.search_off, 'Mất thuốc'),
          tile(IssueKind.outOfMedicine, Icons.inventory_2_outlined, 'Hết thuốc'),
          tile(IssueKind.unsurePill, Icons.help_outline, 'Thuốc trông lạ'),
          tile(IssueKind.unwell, Icons.favorite_border, 'Tôi thấy mệt'),
        ],
      ),
      const SizedBox(height: AppSpacing.sm + 4),
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(68)),
        onPressed: () => _finish(IssueKind.otherIssue),
        child: const Text('Vấn đề khác'),
      ),
      const SizedBox(height: AppSpacing.md),
      Center(child: VoiceButton(onHeard: _onVoice, foreground: AppColors.primary)),
      const SizedBox(height: AppSpacing.md),
      Text('Các con sẽ nhận được câu trả lời.', textAlign: TextAlign.center, style: text.bodyMedium),
    ];
  }

  List<Widget> _after(BuildContext context, TextTheme text, int? groupId) {
    final issue = _issue;
    return [
      Icon(issue == null ? Icons.check_circle : Icons.mark_email_read, size: 72, color: issue == null ? AppColors.ok : AppColors.primary),
      Text(issue == null ? 'Cảm ơn ạ!' : 'Đã báo cho các con', style: text.headlineMedium, textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.lg),
      if (issue == IssueKind.unwell) UnwellHelp(groupId: groupId),
      if (issue == IssueKind.otherIssue) ...[
        Text('Gọi cho con để nói rõ hơn nhé.', style: text.bodyLarge, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.md),
        if (groupId != null) CallChildrenList(groupId: groupId),
      ],
      const SizedBox(height: AppSpacing.md),
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size.fromHeight(72)),
        onPressed: () => context.go('/'),
        child: const Text('Về trang chính'),
      ),
    ];
  }
}
