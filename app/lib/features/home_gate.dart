import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/theme/tokens.dart';
import 'auth/session.dart';
import 'elder/elder_home_screen.dart';
import 'groups/groups_api.dart';
import 'groups/groups_screen.dart';

/// After sign-in: elders get the simple elder home, caregivers get their family groups.
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(meProvider).when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(describeNetworkError(e)),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(onPressed: () => ref.invalidate(meProvider), child: const Text('Thử lại')),
                  TextButton(onPressed: () => ref.read(sessionProvider.notifier).logout(), child: const Text('Đăng xuất')),
                ],
              ),
            ),
          ),
          data: (me) => me.isElder ? ElderHomeScreen(me: me) : const GroupsScreen(),
        );
  }
}
