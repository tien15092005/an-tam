import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/section_label.dart';
import '../../core/theme/tokens.dart';
import 'code_dialog.dart';
import 'groups_api.dart';

/// Parents and children of one family, with the manager's actions (plan §5): add a parent and get the
/// phone pairing code, invite a sibling, hand over the right to set medicines, remove someone.
class GroupMembersView extends ConsumerWidget {
  const GroupMembersView({super.key, required this.group, this.embedded = false});

  final GroupDetail group;

  /// Inside another list (the family tab): no own scrolling.
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
    final me = ref.watch(meProvider).value;
    final elders = group.members.where((m) => m.role == GroupRole.elder).toList();
    final caregivers = group.members.where((m) => m.role != GroupRole.elder).toList();
    final owner = group.iAmOwner;

    Future<void> showPairingCode(GroupMember e) => _run(context, ref, () async {
          final code = await api.pairingCode(group.id, e.userId);
          if (context.mounted) {
            await showCodeDialog(context,
                title: 'Mã ghép máy của ${e.displayName}',
                hint: 'Trên điện thoại của bố mẹ: mở An Tâm, chọn "Tôi là bố / mẹ", nhập mã này. '
                    'Máy cũ (nếu có) sẽ bị đăng xuất.',
                code: code);
          }
        });

    Future<void> caregiverMenu(GroupMember c) async {
      final v = await showModalBottomSheet<String>(
        context: context,
        builder: (sheet) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Giao quyền đặt lịch thuốc'),
              onTap: () => Navigator.pop(sheet, 'transfer'),
            ),
            ListTile(
              leading: Icon(Icons.person_remove_outlined, color: AppColors.danger),
              title: Text('Xóa khỏi gia đình', style: TextStyle(color: AppColors.danger)),
              onTap: () => Navigator.pop(sheet, 'remove'),
            ),
          ]),
        ),
      );
      if (v == null || !context.mounted) return;
      final transfer = v == 'transfer';
      final ok = await confirm(context,
          title: transfer ? 'Giao quyền đặt lịch?' : 'Xóa khỏi gia đình?',
          message: transfer
              ? '${c.displayName} sẽ là người đặt và sửa lịch thuốc. Bạn vẫn xem lịch và nhận báo cáo.'
              : '${c.displayName} sẽ không xem được lịch của bố mẹ nữa.',
          action: transfer ? 'Giao quyền' : 'Xóa');
      if (!ok || !context.mounted) return;
      await _run(
        context,
        ref,
        transfer ? () => api.transferOwnership(group.id, c.userId) : () => api.removeMember(group.id, c.userId),
        done: transfer ? 'Đã giao quyền đặt lịch' : 'Đã xóa ${c.displayName}',
      );
    }

    String elderLine(GroupMember e) {
      final parts = [if (e.birthYear != null) 'Sinh năm ${e.birthYear}', if (e.phone != null) e.phone!];
      if (owner) parts.add('Mã ghép máy');
      return parts.join(' · ');
    }

    final children = <Widget>[
      const SectionLabel('Bố mẹ'),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (elders.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(owner ? 'Chưa có hồ sơ bố mẹ. Thêm để đặt lịch thuốc.' : 'Chưa có hồ sơ bố mẹ.',
                    style: text.bodyMedium),
              ),
            for (final e in elders)
              ListTile(
                leading: InitialAvatar(e.displayName, strong: true),
                title: Text(e.displayName, style: text.titleSmall),
                subtitle: elderLine(e).isEmpty ? null : Text(elderLine(e)),
                trailing: const Icon(Icons.chevron_right),
                onTap: owner
                    ? () => showPairingCode(e)
                    : () => context.push('/groups/${group.id}/elders/${e.userId}/medications'),
              ),
            if (owner)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), foregroundColor: AppColors.primary),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Thêm bố hoặc mẹ'),
                  onPressed: () async {
                    final name =
                        await promptText(context, title: 'Thêm bố / mẹ', label: 'Tên gọi, ví dụ: Bà Lan', action: 'Thêm');
                    if (name != null && context.mounted) {
                      await _run(context, ref, () => api.addElder(group.id, callName: name), done: 'Đã thêm $name');
                    }
                  },
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      const SectionLabel('Các con'),
      Card(
        child: Column(children: [
          for (final c in caregivers)
            ListTile(
              leading: InitialAvatar(c.displayName),
              title: Text(c.userId == me?.id ? '${c.displayName} (bạn)' : c.displayName),
              subtitle: c.role == GroupRole.owner ? const Text('Đặt và sửa lịch thuốc') : null,
              trailing: owner && c.role == GroupRole.member ? const Icon(Icons.more_horiz) : null,
              onTap: owner && c.role == GroupRole.member ? () => caregiverMenu(c) : null,
            ),
        ]),
      ),
      if (owner) ...[
        const SizedBox(height: AppSpacing.xs),
        FilledButton.icon(
          icon: const Icon(Icons.person_add_alt_1, size: 20),
          label: const Text('Mời anh chị em'),
          onPressed: () => _run(context, ref, () async {
            final code = await api.createInvite(group.id);
            if (context.mounted) {
              await showCodeDialog(context,
                  title: 'Mã mời vào gia đình',
                  hint: 'Gửi mã này cho anh chị em qua Zalo. Họ đăng ký tài khoản người con rồi chọn "Nhập mã mời". '
                      'Mỗi mã dùng được một lần.',
                  code: code);
            }
          }),
        ),
      ],
    ];

    return embedded
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
        : ListView(padding: const EdgeInsets.all(AppSpacing.md), children: children);
  }
}

/// Leaving needs care: the one who sets medicines must hand over first, and the last child deletes the family.
Future<void> leaveGroup(BuildContext context, WidgetRef ref, GroupDetail group) async {
  final api = ref.read(groupsApiProvider);
  if (!await confirm(context,
      title: 'Rời gia đình?', message: 'Bạn sẽ không còn theo dõi lịch thuốc của gia đình này.', action: 'Rời')) {
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
        title: 'Xóa thông tin gia đình?',
        message: 'Bạn là người con duy nhất. Rời đi sẽ xóa lịch thuốc của gia đình và đăng xuất điện thoại của bố mẹ.',
        action: 'Xóa');
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
