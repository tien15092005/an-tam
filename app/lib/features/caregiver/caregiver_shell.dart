import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/server_config.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';
import '../auth/session.dart';
import '../care/care_api.dart';
import '../chat/chat_api.dart';
import '../chat/chat_view.dart';
import '../groups/code_dialog.dart' show confirm;
import '../groups/group_members_view.dart';
import '../groups/groups_api.dart';
import '../groups/groups_screen.dart';
import 'schedule_tab.dart';
import 'today_tab.dart';

const _lastGroupKey = 'last_group_id';

/// Caregivers open straight into their last family group, like reopening the last chat.
class CaregiverHome extends ConsumerWidget {
  const CaregiverHome({super.key, required this.me});

  final Me me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (me.groups.isEmpty) return const GroupsScreen();
    final last = ref.read(sharedPreferencesProvider).getInt(_lastGroupKey);
    final id = me.groups.any((g) => g.id == last) ? last! : me.groups.first.id;
    return CaregiverShell(groupId: id);
  }
}

/// One group with the four tabs of plan §10: Hôm nay, Lịch, Nhóm, Cài đặt. The group switcher is the title.
class CaregiverShell extends ConsumerStatefulWidget {
  const CaregiverShell({super.key, required this.groupId, this.initialTab = 0});

  final int groupId;
  final int initialTab;

  @override
  ConsumerState<CaregiverShell> createState() => _CaregiverShellState();
}

class _CaregiverShellState extends ConsumerState<CaregiverShell> {
  late int _tab = widget.initialTab;
  int? _elder;

  @override
  void initState() {
    super.initState();
    ref.read(sharedPreferencesProvider).setInt(_lastGroupKey, widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(groupDetailProvider(widget.groupId));
    final me = ref.watch(meProvider).value;
    final alerts = ref.watch(openAlertsProvider(widget.groupId)).value?.length ?? 0;
    final unread = ref.watch(chatUnreadProvider).value?[widget.groupId] ?? 0;
    final group = detail.value;
    final elders = group?.members.where((m) => m.role == GroupRole.elder).toList() ?? const [];
    final elder = elders.any((e) => e.userId == _elder) ? _elder : (elders.isEmpty ? null : elders.first.userId);

    return Scaffold(
      appBar: AppBar(
        title: PopupMenuButton<int>(
          tooltip: 'Chuyển nhóm',
          onSelected: (id) => id < 0 ? context.push('/groups') : context.go('/groups/$id'),
          itemBuilder: (_) => [
            for (final g in me?.groups ?? const <GroupSummary>[])
              PopupMenuItem(
                value: g.id,
                child: Row(children: [
                  Icon(g.id == widget.groupId ? Icons.radio_button_checked : Icons.radio_button_off, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(child: Text(g.name)),
                ]),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: -1, child: Text('Tạo nhóm hoặc nhập mã mời')),
          ],
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(group?.name ?? 'Nhóm', overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down),
          ]),
        ),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(describeNetworkError(e), textAlign: TextAlign.center),
              TextButton(onPressed: () => ref.invalidate(groupDetailProvider(widget.groupId)), child: const Text('Thử lại')),
              TextButton(onPressed: () => context.go('/groups'), child: const Text('Danh sách nhóm')),
            ]),
          ),
        ),
        data: (g) => IndexedStack(index: _tab, children: [
          TodayTab(group: g, elderUserId: elder, onElderChanged: (id) => setState(() => _elder = id)),
          ScheduleTab(group: g, elderUserId: elder, onElderChanged: (id) => setState(() => _elder = id)),
          // Built only while open, so messages are marked read only when someone actually looks.
          _tab == 2 ? ChatView(group: g, onOpenAlerts: () => setState(() => _tab = 0)) : const SizedBox.shrink(),
          _SettingsTab(group: g),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          ref.invalidate(chatUnreadProvider);
        },
        destinations: [
          NavigationDestination(
            icon: Badge(isLabelVisible: alerts > 0, label: Text('$alerts'), child: const Icon(Icons.today_outlined)),
            selectedIcon: Badge(isLabelVisible: alerts > 0, label: Text('$alerts'), child: const Icon(Icons.today)),
            label: 'Hôm nay',
          ),
          const NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Lịch'),
          NavigationDestination(
            icon: Badge(isLabelVisible: unread > 0 && _tab != 2, label: Text('$unread'), child: const Icon(Icons.forum_outlined)),
            selectedIcon: const Icon(Icons.forum),
            label: 'Nhóm',
          ),
          const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Cài đặt'),
        ],
      ),
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab({required this.group});

  final GroupDetail group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    final text = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
      if (me != null) ...[
        Text(me.displayName, style: text.titleLarge),
        Text(group.iAmOwner ? 'Trưởng nhóm "${group.name}"' : 'Thành viên nhóm "${group.name}"', style: text.bodyMedium),
        const SizedBox(height: AppSpacing.md),
      ],
      Card(
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Nhóm khác, tạo nhóm, nhập mã mời'),
            onTap: () => context.push('/groups'),
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Máy chủ và thử nghiệm'),
            onTap: () => context.push('/connection'),
          ),
        ]),
      ),
      const SizedBox(height: AppSpacing.md),
      Text('Bố mẹ và các con', style: text.titleMedium),
      GroupMembersView(group: group, embedded: true),
      const SizedBox(height: AppSpacing.xl),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
        icon: const Icon(Icons.exit_to_app),
        label: const Text('Rời nhóm'),
        onPressed: () => leaveGroup(context, ref, group),
      ),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text('Đăng xuất'),
        onPressed: () => ref.read(sessionProvider.notifier).logout(),
      ),
      const SizedBox(height: AppSpacing.xl),
      TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
        icon: const Icon(Icons.delete_forever),
        label: const Text('Xóa tài khoản và dữ liệu'),
        onPressed: () => _deleteAccount(context, ref),
      ),
    ]);
  }
}

Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
  final ok = await confirm(context,
      title: 'Xóa tài khoản?',
      message: 'Tài khoản, tin nhắn của bạn sẽ bị xóa và bạn rời mọi nhóm. Nếu bạn là người con duy nhất của một nhóm, '
          'nhóm đó cùng thông tin của bố mẹ và ảnh thuốc cũng bị xóa. Không thể hoàn tác.',
      action: 'Xóa vĩnh viễn');
  if (!ok) return;
  try {
    await ref.read(dioProvider).delete<void>('/api/me', queryParameters: {'confirm': true});
    await ref.read(sessionProvider.notifier).signOutLocally();
  } catch (e) {
    if (!context.mounted) return;
    final msg = errorCode(e) == 'transfer_required'
        ? 'Bạn là trưởng nhóm có các anh chị em khác. Hãy chuyển quyền trưởng nhóm trước.'
        : describeNetworkError(e);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
