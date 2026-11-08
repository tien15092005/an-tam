import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../auth/session.dart';
import '../groups/code_dialog.dart';
import '../groups/groups_api.dart';

/// Elder home after pairing. Phase 3: confirms the connection and shows the family;
/// today's medicines arrive in Phase 4–5.
class ElderHomeScreen extends ConsumerWidget {
  const ElderHomeScreen({super.key, required this.me});

  final Me me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupId = me.groups.isEmpty ? null : me.groups.first.id;
    final detail = groupId == null ? null : ref.watch(groupDetailProvider(groupId));
    return Theme(
      data: AppTheme.build(UiDensity.elder),
      child: Builder(builder: (context) {
        final text = Theme.of(context).textTheme;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text('Xin chào,', style: text.bodyLarge),
                Text(me.displayName, style: text.headlineMedium),
                const SizedBox(height: AppSpacing.lg),
                Card(
                  color: AppColors.okSoft,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.ok, size: 40),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            groupId == null ? 'Chưa thuộc nhóm nào' : 'Đã kết nối với ${me.groups.first.name}',
                            style: text.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Thuốc hôm nay sẽ hiện ở đây khi con đặt lịch.', style: text.bodyLarge),
                const SizedBox(height: AppSpacing.lg),
                if (detail != null)
                  detail.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(describeNetworkError(e)),
                    data: (g) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Con cháu trong nhà', style: text.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        for (final c in g.members.where((m) => m.role != GroupRole.elder))
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.phone, color: AppColors.navy, size: 32),
                              title: Text(c.displayName, style: text.titleMedium),
                              subtitle: Text(c.phone ?? 'Chưa có số điện thoại', style: text.bodyLarge),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                TextButton(
                  onPressed: () async {
                    if (await confirm(context,
                        title: 'Đăng xuất?', message: 'Sẽ cần nhập lại mã của con.', action: 'Đăng xuất')) {
                      await ref.read(sessionProvider.notifier).logout();
                    }
                  },
                  child: const Text('Đăng xuất'),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
