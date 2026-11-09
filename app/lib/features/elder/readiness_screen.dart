import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../reminder/alarm_channel.dart';

/// Re-read every time the screen is shown or the user comes back from Android settings.
final readinessProvider = FutureProvider.autoDispose<AlarmReadiness>((ref) => AlarmChannel.readiness());

/// "Kiểm tra máy" (plan §9): everything the phone needs for alarms that ring, speak and show over
/// the lock screen, each with a button to the right Android settings page. Meant for the caregiver
/// setting up the elder's phone.
class ReadinessScreen extends ConsumerStatefulWidget {
  const ReadinessScreen({super.key});

  @override
  ConsumerState<ReadinessScreen> createState() => _ReadinessScreenState();
}

class _ReadinessScreenState extends ConsumerState<ReadinessScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(readinessProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(readinessProvider);
    return Theme(
      data: AppTheme.build(UiDensity.elder),
      child: Builder(builder: (context) {
        final text = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(title: const Text('Kiểm tra máy')),
          body: r.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text('Chỉ kiểm tra được trên điện thoại Android.', style: text.bodyLarge)),
            data: (r) => RefreshIndicator(
              onRefresh: () => ref.refresh(readinessProvider.future),
              child: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
                Card(
                  color: r.alarmsReady ? AppColors.okSoft : AppColors.warnSoft,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(children: [
                      Icon(r.alarmsReady ? Icons.verified : Icons.warning_amber,
                          color: r.alarmsReady ? AppColors.ok : AppColors.warn, size: 40),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(r.alarmsReady ? 'Máy đã sẵn sàng nhắc thuốc.' : 'Còn mục chưa bật. Nhờ con bật giúp.',
                            style: text.titleMedium),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _Item(
                    ok: r.notifications,
                    title: 'Thông báo',
                    why: 'Để báo thức hiện lên và kêu.',
                    onFix: () async {
                      await AlarmChannel.requestNotificationPermission();
                      await AlarmChannel.openSettings('notifications');
                    }),
                _Item(ok: r.exactAlarms, title: 'Báo thức đúng giờ', why: 'Để báo đúng phút.', onFix: () => AlarmChannel.openSettings('exactAlarms')),
                _Item(
                    ok: r.fullScreen,
                    title: 'Hiện trên màn hình khóa',
                    why: 'Để màn hình báo tự bật lên khi máy đang khóa.',
                    onFix: () => AlarmChannel.openSettings('fullScreen')),
                _Item(
                    ok: r.batteryUnrestricted,
                    title: 'Không giới hạn pin',
                    why: 'Để máy không tắt An Tâm khi tiết kiệm pin.',
                    onFix: () => AlarmChannel.openSettings('battery')),
                _Item(
                    ok: r.vietnameseVoice,
                    title: 'Giọng đọc tiếng Việt',
                    why: 'Để máy đọc tên thuốc. Thiếu thì vẫn rung và hiện chữ, nhưng không đọc.',
                    onFix: () => AlarmChannel.openSettings('tts')),
                _Item(
                    ok: r.microphone,
                    optional: true,
                    title: 'Micro (không bắt buộc)',
                    why: 'Để trả lời bằng giọng nói. Bấm "Bấm để nói" trên màn hình báo để bật.',
                    onFix: () => AlarmChannel.openSettings('microphone')),
                const SizedBox(height: AppSpacing.md),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('Hướng dẫn cho máy Samsung', style: text.titleMedium),
                  childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
                  children: [
                    Text(
                      '1. Cài đặt → Ứng dụng → An Tâm → Pin → chọn "Không hạn chế".\n'
                      '2. Cài đặt → Chăm sóc thiết bị → Pin → Giới hạn sử dụng nền: bỏ An Tâm khỏi "Ứng dụng ngủ" và "Ứng dụng ngủ sâu".\n'
                      '3. Cài đặt → Ứng dụng → An Tâm → Thông báo: bật tất cả, cho phép hiện trên màn hình khóa.\n'
                      '4. Cài đặt → Quản lý chung → Ngôn ngữ và bàn phím → Chuyển văn bản thành giọng nói: chọn giọng tiếng Việt '
                      '(Google), tải dữ liệu giọng nếu được hỏi.',
                      style: text.bodyLarge,
                    ),
                  ],
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.ok, required this.title, required this.why, required this.onFix, this.optional = false});

  final bool ok;
  final bool optional;
  final String title;
  final String why;
  final Future<void> Function() onFix;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = ok ? AppColors.ok : (optional ? AppColors.muted : AppColors.danger);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(ok ? Icons.check_circle : Icons.cancel, color: color, size: 32),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title, style: text.titleMedium)),
          ]),
          // Status in words too, not only colour (plan §9).
          Text(ok ? 'Đã bật' : (optional ? 'Chưa bật' : 'Chưa bật — cần bật'), style: text.bodyLarge?.copyWith(color: color)),
          Text(why, style: text.bodyLarge),
          if (!ok)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(onPressed: onFix, icon: const Icon(Icons.settings), label: const Text('Mở cài đặt')),
            ),
        ]),
      ),
    );
  }
}
