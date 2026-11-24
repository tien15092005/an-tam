import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/tokens.dart';
import '../../reminder/schedule_sync.dart';

Future<void> callNumber(String phone) => launchUrl(Uri(scheme: 'tel', path: phone));

/// The caregivers with a phone number, biggest buttons first; works offline from the saved list.
class CallChildrenList extends ConsumerWidget {
  const CallChildrenList({super.key, required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final contacts = ref.watch(elderContactsProvider(groupId));
    return contacts.when(
      loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.md), child: LinearProgressIndicator()),
      error: (_, _) => Text('Chưa có số điện thoại của con.', style: text.bodyLarge),
      data: (list) {
        final callable = list.where((c) => c.phone != null && c.phone!.isNotEmpty).toList();
        if (callable.isEmpty) return Text('Chưa có số điện thoại của con.', style: text.bodyLarge);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final c in callable)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.navy, minimumSize: const Size.fromHeight(72)),
                onPressed: () => callNumber(c.phone!),
                icon: const Icon(Icons.phone, size: 32),
                label: Text('Gọi ${c.name}'),
              ),
            ),
        ]);
      },
    );
  }
}

/// Shown after "Tôi thấy không khỏe": who to call, and the emergency number. No medical advice.
class UnwellHelp extends StatelessWidget {
  const UnwellHelp({super.key, required this.groupId});

  final int? groupId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (groupId != null) CallChildrenList(groupId: groupId!),
      const SizedBox(height: AppSpacing.sm),
      Card(
        color: AppColors.dangerSoft,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(children: [
            Icon(Icons.emergency, color: AppColors.danger, size: 40),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text('Nếu nguy cấp, gọi cấp cứu 115.', style: text.titleMedium)),
          ]),
        ),
      ),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, minimumSize: const Size.fromHeight(72)),
        onPressed: () => callNumber('115'),
        icon: const Icon(Icons.local_hospital, size: 32),
        label: const Text('Gọi 115'),
      ),
    ]);
  }
}

Future<void> showCallSheet(BuildContext context, int groupId) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Gọi cho con', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            CallChildrenList(groupId: groupId),
          ]),
        ),
      ),
    );
