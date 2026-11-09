import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';
import 'code_dialog.dart';
import 'groups_api.dart';

/// The "Nhóm" tab: elders and caregivers, with the owner's management actions (plan §5).
class GroupMembersView extends ConsumerWidget {
  const GroupMembersView({super.key, required this.group, this.embedded = false});

  final GroupDetail group;

  /// Inside another list (the settings tab): no own scrolling.
  final bool embedded;

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action, {String? done}) async {
    try {
      await action();
      ref.invalidate(groupDetailProvider(group.id));
      ref.invalidate(meProvider);
      if (done != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeNetworkError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(groupsApiProvider);
    final text = Theme.of(context).textTheme;
    final elders = group.members.where((m) => m.role == GroupRole.elder).toList();
    final caregivers = group.members.where((m) => m.role != GroupRole.elder).toList();

    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: embedded ? EdgeInsets.zero : const EdgeInsets.all(AppSpacing.md),
      children: [
        Chip(
          avatar: Icon(group.iAmOwner ? Icons.star : Icons.person, size: 18),
          label: Text(group.iAmOwner ? 'Bạn là trưởng nhóm' : 'Bạn là thành viên'),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Bố mẹ', style: text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (elders.isEmpty) const Text('Chưa có hồ sơ bố mẹ.'),
        for (final e in elders)
          Card(
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: AppColors.primarySoft, child: Icon(Icons.elderly, color: AppColors.primary)),
              title: Text(e.displayName),
              subtitle: Text([
                if (e.birthYear != null) 'Sinh năm ${e.birthYear}',
                if (e.phone != null) e.phone!,
                'Bấm để xem thuốc',
              ].join(' · ')),
              onTap: () => context.push('/groups/${group.id}/elders/${e.userId}/medications'),
              trailing: group.iAmOwner
                  ? TextButton(
                      onPressed: () => _run(context, ref, () async {
                        final code = await api.pairingCode(group.id, e.userId);
                        if (context.mounted) {
                          await showCodeDialog(context,
                              title: 'Mã ghép máy của ${e.displayName}',
                              hint: 'Trên điện thoại của bố mẹ: mở An Tâm, chọn "Tôi là bố / mẹ", nhập mã này. '
                                  'Máy cũ (nếu có) sẽ bị đăng xuất.',
                              code: code);
                        }
                      }),
                      child: const Text('Mã ghép máy'),
                    )
                  : null,
            ),
          ),
        if (group.iAmOwner)
          TextButton.icon(
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Thêm bố / mẹ'),
            onPressed: () async {
              final name = await promptText(context, title: 'Thêm bố / mẹ', label: 'Tên gọi, ví dụ: Bà Lan', action: 'Thêm');
              if (name != null && context.mounted) {
                await _run(context, ref, () => api.addElder(group.id, callName: name), done: 'Đã thêm $name');
              }
            },
          ),
        const SizedBox(height: AppSpacing.md),
        Text('Người con', style: text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final c in caregivers)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.navySoft,
                child: Icon(c.role == GroupRole.owner ? Icons.star : Icons.person, color: AppColors.navy),
              ),
              title: Text(c.displayName),
              subtitle: Text(c.role == GroupRole.owner ? 'Trưởng nhóm' : 'Thành viên'),
              trailing: group.iAmOwner && c.role == GroupRole.member
                  ? PopupMenuButton<String>(
                      onSelected: (v) async {
                        final transfer = v == 'transfer';
                        final ok = await confirm(context,
                            title: transfer ? 'Chuyển quyền trưởng nhóm?' : 'Xóa khỏi nhóm?',
                            message: transfer
                                ? '${c.displayName} sẽ là người đặt lịch cho cả nhóm. Bạn trở thành thành viên.'
                                : '${c.displayName} sẽ không xem được nhóm nữa.',
                            action: transfer ? 'Chuyển quyền' : 'Xóa');
                        if (!ok || !context.mounted) return;
                        await _run(
                          context,
                          ref,
                          transfer
                              ? () => api.transferOwnership(group.id, c.userId)
                              : () => api.removeMember(group.id, c.userId),
                          done: transfer ? 'Đã chuyển quyền' : 'Đã xóa ${c.displayName} khỏi nhóm',
                        );
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'transfer', child: Text('Chuyển quyền trưởng nhóm')),
                        PopupMenuItem(value: 'remove', child: Text('Xóa khỏi nhóm')),
                      ],
                    )
                  : null,
            ),
          ),
        if (group.iAmOwner)
          TextButton.icon(
            icon: const Icon(Icons.group_add),
            label: const Text('Mời anh chị em'),
            onPressed: () => _run(context, ref, () async {
              final code = await api.createInvite(group.id);
              if (context.mounted) {
                await showCodeDialog(context,
                    title: 'Mã mời vào nhóm',
                    hint: 'Gửi mã này cho anh chị em qua Zalo. Họ đăng ký tài khoản người con rồi chọn "Nhập mã mời". '
                        'Mỗi mã dùng được một lần.',
                    code: code);
              }
            }),
          ),
      ],
    );
  }
}

/// Leaving needs care: an owner must hand over first, and the last caregiver deletes the group.
Future<void> leaveGroup(BuildContext context, WidgetRef ref, GroupDetail group) async {
  final api = ref.read(groupsApiProvider);
  if (!await confirm(context, title: 'Rời nhóm?', message: 'Bạn sẽ không còn theo dõi lịch của nhóm này.', action: 'Rời nhóm')) {
    return;
  }
  try {
    await api.leave(group.id);
  } catch (e) {
    if (errorCode(e) != 'confirm_delete_required' || !context.mounted) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeNetworkError(e))));
      return;
    }
    final sure = await confirm(context,
        title: 'Xóa nhóm?',
        message: 'Bạn là người con duy nhất trong nhóm. Rời nhóm sẽ xóa nhóm và đăng xuất điện thoại của bố mẹ.',
        action: 'Xóa nhóm');
    if (!sure) return;
    try {
      await api.leave(group.id, confirmDelete: true);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeNetworkError(e))));
      return;
    }
  }
  ref.invalidate(meProvider);
  if (context.mounted) context.go('/');
}
