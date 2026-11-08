import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../reminder/alarm_channel.dart';

/// Full-screen alarm shown over the lock screen. Phase 2 spike version: confirming or snoozing
/// stops the native ringing; the "any problem?" question and reporting come in Phase 5.
class AlarmScreen extends StatelessWidget {
  const AlarmScreen({super.key});

  Future<void> _snooze(BuildContext context) async {
    await AlarmChannel.stopRinging();
    await AlarmChannel.schedule(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000 % 1000000,
      at: DateTime.now().add(const Duration(minutes: 10)),
      title: 'Nhắc lại: đến giờ uống thuốc',
      speech: 'Đến giờ uống thuốc rồi ạ. Uống xong, bấm nút màu xanh.',
    );
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.build(UiDensity.elder),
      child: Builder(builder: (context) {
        final text = Theme.of(context).textTheme;
        return PopScope(
          canPop: false, // The alarm only ends by confirming or snoozing.
          child: Scaffold(
            backgroundColor: AppColors.primary,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    const Icon(Icons.alarm, size: 96, color: Colors.white),
                    const SizedBox(height: AppSpacing.md),
                    Text('Đến giờ uống thuốc',
                        textAlign: TextAlign.center, style: text.headlineMedium?.copyWith(color: Colors.white)),
                    const Spacer(),
                    FilledButton.icon(
                      key: const Key('confirmTaken'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.ok,
                        minimumSize: const Size.fromHeight(96),
                      ),
                      onPressed: () async {
                        await AlarmChannel.stopRinging();
                        if (context.mounted) context.go('/');
                      },
                      icon: const Icon(Icons.check_circle, size: 40),
                      label: const Text('ĐÃ UỐNG RỒI'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70, width: 2),
                      ),
                      onPressed: () => _snooze(context),
                      child: const Text('Nhắc lại sau 10 phút'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
