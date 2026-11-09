import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../care/care_api.dart' show hhmmOf;
import '../groups/code_dialog.dart' show confirm;
import '../groups/group_members_view.dart';
import '../groups/groups_api.dart';
import 'chat_api.dart';
import 'chat_controller.dart';

/// "Nhóm" tab: the family chat (text only, plan §10) with the member list one tap away.
/// System lines (alerts, schedule changes) sit in the middle; an alert line opens "Hôm nay".
class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key, required this.group, required this.onOpenAlerts});

  final GroupDetail group;
  final VoidCallback onOpenAlerts;

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Reversed list: reaching the end means reaching the oldest message.
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
        ref.read(chatProvider(widget.group.id).notifier).loadOlder();
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(chatProvider(widget.group.id).notifier).send(text);
  }

  void _openMembers() => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('Thành viên · ${widget.group.name}')),
          body: GroupMembersView(group: widget.group),
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider(widget.group.id));
    final me = ref.watch(meProvider).value?.id;
    final text = Theme.of(context).textTheme;
    final items = state.messages.reversed.toList();
    return Column(children: [
      Material(
        color: AppColors.navySoft,
        child: ListTile(
          leading: const Icon(Icons.groups, color: AppColors.navy),
          title: Text('${widget.group.members.length} thành viên'),
          subtitle: Text(state.live ? 'Đang kết nối trực tiếp' : 'Đang kết nối lại...',
              style: text.bodySmall?.copyWith(color: state.live ? AppColors.ok : AppColors.muted)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _openMembers,
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => ref.read(chatProvider(widget.group.id).notifier).reload(),
          child: state.loading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? ListView(children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(state.error ?? 'Chưa có tin nhắn. Các con bàn lịch thuốc ở đây; '
                            'cảnh báo và thay đổi lịch cũng hiện ở đây.', textAlign: TextAlign.center),
                      ),
                    ])
                  : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _Bubble(
                        m: items[i],
                        mine: items[i].senderId != null && items[i].senderId == me,
                        onAlert: widget.onOpenAlerts,
                        onRetry: () => ref.read(chatProvider(widget.group.id).notifier).retry(items[i]),
                        onDelete: () async {
                          if (await confirm(context, title: 'Xóa tin nhắn?', message: 'Mọi người sẽ không thấy nội dung nữa.',
                              action: 'Xóa')) {
                            await ref.read(chatProvider(widget.group.id).notifier).delete(items[i]);
                          }
                        },
                      ),
                    ),
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Nhắn cho cả nhà...', counterText: ''),
                onSubmitted: (_) => _send(),
              ),
            ),
            IconButton.filled(tooltip: 'Gửi', onPressed: _send, icon: const Icon(Icons.send)),
          ]),
        ),
      ),
    ]);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m, required this.mine, required this.onAlert, required this.onRetry, required this.onDelete});

  final ChatMessage m;
  final bool mine;
  final VoidCallback onAlert;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (m.system) {
      final alert = m.alertId != null;
      return Center(
        child: InkWell(
          onTap: alert ? onAlert : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: alert ? AppColors.dangerSoft : AppColors.navySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(alert ? Icons.report : Icons.info_outline, size: 16, color: alert ? AppColors.danger : AppColors.navy),
              const SizedBox(width: AppSpacing.xs),
              Flexible(child: Text('${m.body ?? ''} · ${hhmmOf(m.createdAt)}', style: text.bodySmall)),
            ]),
          ),
        ),
      );
    }
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: mine ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!mine) Text(m.senderName ?? '', style: text.labelMedium?.copyWith(color: AppColors.navy)),
        Text(m.deleted ? 'Tin nhắn đã bị xóa' : (m.body ?? ''),
            style: m.deleted ? text.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: AppColors.muted) : text.bodyMedium),
        Text(
          m.failed ? 'Chưa gửi được · bấm để gửi lại' : (m.pending ? 'Đang gửi...' : hhmmOf(m.createdAt)),
          style: text.labelSmall?.copyWith(color: m.failed ? AppColors.danger : AppColors.muted),
        ),
      ]),
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: m.failed ? onRetry : null,
        onLongPress: mine && !m.pending && !m.deleted ? onDelete : null,
        child: bubble,
      ),
    );
  }
}
