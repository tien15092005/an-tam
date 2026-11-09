import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';
import '../auth/session.dart';
import 'code_dialog.dart';
import 'groups_api.dart';

/// Caregiver home: the family groups this person belongs to, like a list of group chats.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(meProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeNetworkError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final api = ref.read(groupsApiProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gia đình của bạn'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'logout') await ref.read(sessionProvider.notifier).logout();
              if (v == 'server' && context.mounted) context.push('/connection');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'server', child: Text('Máy chủ và thử nghiệm')),
              PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(meProvider.future),
        child: me.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [Text(describeNetworkError(e))]),
          data: (me) => ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text('Xin chào, ${me.displayName}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              if (me.groups.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('Bạn chưa ở nhóm nào. Tạo nhóm cho gia đình mình, hoặc nhập mã mời anh chị em gửi.'),
                  ),
                ),
              for (final g in me.groups) ...[
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.navySoft,
                      child: Icon(Icons.home, color: AppColors.navy),
                    ),
                    title: Text(g.name),
                    subtitle: Text(g.myRole == GroupRole.owner ? 'Bạn là trưởng nhóm' : 'Thành viên'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/groups/${g.id}'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Tạo nhóm gia đình'),
                onPressed: () async {
                  final name = await promptText(context, title: 'Tạo nhóm', label: 'Tên nhóm, ví dụ: Nhà bà Lan', action: 'Tạo');
                  if (name != null && context.mounted) await _run(context, ref, () => api.create(name));
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.group_add),
                label: const Text('Nhập mã mời'),
                onPressed: () async {
                  final code = await promptText(context,
                      title: 'Tham gia nhóm', label: 'Mã mời 10 ký tự', action: 'Tham gia', caps: TextCapitalization.characters);
                  if (code != null && context.mounted) await _run(context, ref, () => api.acceptInvite(code));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
