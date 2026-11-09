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
    Widget option(IssueKind kind, IconData icon, String label) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(72),
              alignment: Alignment.centerLeft,
              foregroundColor: kind == IssueKind.unwell ? AppColors.danger : AppColors.ink,
            ),
            onPressed: () => _finish(kind),
            icon: Icon(icon, size: 32),
            label: Text(label),
          ),
        );
    return [
      Icon(widget.args.taken ? Icons.check_circle : Icons.info, size: 64, color: widget.args.taken ? AppColors.ok : AppColors.warn),
      Semantics(
        header: true,
        child: Text(widget.args.taken ? 'Có gặp vấn đề gì không?' : 'Vì sao không uống được?',
            style: text.headlineMedium, textAlign: TextAlign.center),
      ),
      const SizedBox(height: AppSpacing.lg),
      if (widget.args.taken)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: FilledButton.icon(
            key: const Key('noProblem'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.ok, minimumSize: const Size.fromHeight(96)),
            onPressed: () => _finish(null),
            icon: const Icon(Icons.thumb_up, size: 40),
            label: const Text('KHÔNG CÓ GÌ'),
          ),
        ),
      option(IssueKind.lostMedicine, Icons.search_off, 'Mất thuốc'),
      option(IssueKind.outOfMedicine, Icons.remove_shopping_cart, 'Hết thuốc'),
      option(IssueKind.unsurePill, Icons.help_outline, 'Thuốc trông khác, không chắc'),
      option(IssueKind.unwell, Icons.sick, 'Tôi thấy không khỏe'),
      option(IssueKind.otherIssue, Icons.more_horiz, 'Vấn đề khác'),
      const SizedBox(height: AppSpacing.sm),
      Center(child: VoiceButton(onHeard: _onVoice, foreground: AppColors.navy)),
    ];
  }

  List<Widget> _after(BuildContext context, TextTheme text, int? groupId) {
    final issue = _issue;
    return [
      Icon(issue == null ? Icons.favorite : Icons.mark_email_read, size: 72, color: issue == null ? AppColors.ok : AppColors.navy),
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
