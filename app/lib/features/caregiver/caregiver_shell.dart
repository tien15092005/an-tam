import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/server_config.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';
import '../auth/password_screen.dart';
import '../auth/session.dart';
import '../care/care_api.dart';
import '../groups/code_dialog.dart';
import '../groups/group_members_view.dart';
import '../groups/groups_api.dart';
import '../groups/groups_screen.dart';
import 'schedule_tab.dart';
import 'today_tab.dart';

const _lastGroupKey = 'last_group_id';

/// Caregivers open straight into their family. With no family yet they create one or enter an invite code.
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

/// Three tabs and nothing else (super-minimal caregiver app): Hôm nay, Thuốc, Gia đình.
class CaregiverShell extends ConsumerStatefulWidget {
  const CaregiverShell({super.key, required this.groupId, this.initialTab = 0});

  final int groupId;
  final int initialTab;

  @override
  ConsumerState<CaregiverShell> createState() => _CaregiverShellState();
}

class _CaregiverShellState extends ConsumerState<CaregiverShell> {
  late int _tab = widget.initialTab.clamp(0, 2);
  int? _elder;

  @override
  void initState() {
    super.initState();
    ref.read(sharedPreferencesProvider).setInt(_lastGroupKey, widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(groupDetailProvider(widget.groupId));
    final alerts = ref.watch(openAlertsProvider(widget.groupId)).value?.length ?? 0;
    final elders = detail.value?.members.where((m) => m.role == GroupRole.elder).toList() ?? const [];
    final elder = elders.any((e) => e.userId == _elder) ? _elder : (elders.isEmpty ? null : elders.first.userId);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 40, color: AppColors.muted),
                  const SizedBox(height: AppSpacing.sm),
                  Text(describeNetworkError(e), textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(onPressed: () => ref.invalidate(groupDetailProvider(widget.groupId)), child: const Text('Thử lại')),
                  TextButton(onPressed: () => context.push('/connection'), child: const Text('Kiểm tra địa chỉ máy chủ')),
                ],
              ),
            ),
          ),
          data: (g) => IndexedStack(
            index: _tab,
            children: [
              TodayTab(group: g, elderUserId: elder, onElderChanged: (id) => setState(() => _elder = id)),
              ScheduleTab(group: g, elderUserId: elder, onElderChanged: (id) => setState(() => _elder = id)),
              FamilyTab(group: g),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            NavigationDestination(
              icon: Badge(isLabelVisible: alerts > 0, label: Text('$alerts'), child: const Icon(Icons.home_outlined)),
              selectedIcon: Badge(isLabelVisible: alerts > 0, label: Text('$alerts'), child: const Icon(Icons.home)),
              label: 'Hôm nay',
            ),
            const NavigationDestination(
              icon: Icon(Icons.medication_outlined),
              selectedIcon: Icon(Icons.medication),
              label: 'Thuốc',
            ),
            const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Gia đình'),
          ],
        ),
      ),
    );
  }
}

/// "Gia đình": parents and children in one place, then the few settings, then account removal.
class FamilyTab extends ConsumerWidget {
  const FamilyTab({super.key, required this.group});

  final GroupDetail group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    final text = Theme.of(context).textTheme;
    final others = (me?.groups.length ?? 1) > 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      children: [
        Text('Gia đình', style: text.headlineSmall?.copyWith(fontSize: 24)),
        if (me != null) Text('Bạn đăng nhập là ${me.displayName}', style: text.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        GroupMembersView(group: group, embedded: true),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Column(
            children: [
              if (others)
                ListTile(
                  title: const Text('Gia đình khác'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/groups'),
                ),
              ListTile(
                title: const Text('Đổi mật khẩu'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PasswordScreen(reset: false))),
              ),
              ListTile(
                title: const Text('Địa chỉ máy chủ'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/connection'),
              ),
              ListTile(
                title: const Text('Đăng xuất'),
                onTap: () async {
                  if (await confirm(
                    context,
                    title: 'Đăng xuất?',
                    message: 'Bạn sẽ thôi nhận báo cáo trên máy này.',
                    action: 'Đăng xuất',
                  )) {
                    await ref.read(sessionProvider.notifier).logout();
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!group.iAmOwner)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => leaveGroup(context, ref, group),
            child: const Text('Rời gia đình này'),
          ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: () => _deleteAccount(context, ref),
          child: const Text('Xóa tài khoản'),
        ),
      ],
    );
  }
}

Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
  final ok = await confirm(
    context,
    title: 'Xóa tài khoản?',
    message:
        'Tài khoản của bạn sẽ bị xóa. Nếu bạn là người con duy nhất trong gia đình, '
        'thông tin của bố mẹ và ảnh thuốc cũng bị xóa. Không thể hoàn tác.',
    action: 'Xóa vĩnh viễn',
  );
  if (!ok) return;
  try {
    await ref.read(dioProvider).delete<void>('/api/me', queryParameters: {'confirm': true});
    await ref.read(sessionProvider.notifier).signOutLocally();
  } catch (e) {
    if (!context.mounted) return;
    final msg = errorCode(e) == 'transfer_required'
        ? 'Bạn đang quản lý lịch thuốc và còn anh chị em khác. Hãy giao quyền quản lý cho một người trước.'
        : describeNetworkError(e);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
