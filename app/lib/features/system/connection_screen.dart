import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/server_config.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';
import '../auth/session.dart';
import 'server_health.dart';

/// Phase 1 screen: shows whether the app reaches the backend (and the backend the AI service),
/// and lets the user change the server address when the tunnel URL changes.
class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  late final TextEditingController _url = TextEditingController(text: ref.read(serverUrlProvider));
  String? _urlError;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = await ref.read(serverUrlProvider.notifier).save(_url.text);
    setState(() => _urlError = error);
    if (error == null && mounted) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu địa chỉ máy chủ')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final health = ref.watch(serverHealthProvider);
    final theme = Theme.of(context);
    // On a paired parent's phone the address is locked: a grandchild playing with it would stop all syncing.
    // It opens again only when the phone has to be paired again (a new code, maybe a new server).
    final session = ref.watch(sessionProvider).value;
    final locked = session != null && session.isElder && !session.expired;

    return Scaffold(
      appBar: AppBar(title: const Text('An Tâm · Kiểm tra kết nối')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(serverHealthProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: health.when(
                  loading: () => const _StatusRow(label: 'Đang kiểm tra máy chủ…', state: _Lamp.checking),
                  error: (e, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _StatusRow(label: 'Máy chủ', state: _Lamp.down),
                      const SizedBox(height: AppSpacing.sm),
                      Text(describeNetworkError(e), style: theme.textTheme.bodyMedium),
                    ],
                  ),
                  data: (h) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusRow(label: 'Máy chủ', state: h.backendUp ? _Lamp.up : _Lamp.down),
                      const SizedBox(height: AppSpacing.sm),
                      _StatusRow(label: 'Dịch vụ AI', state: h.aiUp ? _Lamp.up : _Lamp.down),
                      if (h.serverTime != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text('Giờ máy chủ: ${h.serverTime!.toLocal()}', style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(serverHealthProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Kiểm tra lại'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Địa chỉ máy chủ', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (locked)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text('Máy của bố mẹ đã ghép xong nên không đổi địa chỉ ở đây. '
                    'Khi cần, đăng xuất trên máy này rồi ghép lại bằng mã mới.', style: theme.textTheme.bodyMedium),
              ),
            TextField(
              key: const Key('serverUrlField'),
              controller: _url,
              enabled: !locked,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'https://...trycloudflare.com',
                errorText: _urlError,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: FilledButton(onPressed: locked ? null : _save, child: const Text('Lưu'))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: locked ? null : () async {
                      await ref.read(serverUrlProvider.notifier).reset();
                      _url.text = ref.read(serverUrlProvider);
                      setState(() => _urlError = null);
                    },
                    child: const Text('Mặc định'),
                  ),
                ),
              ],
            ),
            if (kDebugMode) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Xem thử giao diện (chỉ bản thử)', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => context.push('/preview/elder'),
                icon: const Icon(Icons.accessibility_new),
                label: const Text('Chế độ người già'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => context.push('/spike/alarm'),
                icon: const Icon(Icons.alarm),
                label: const Text('Thử nghiệm báo thức'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _Lamp { checking, up, down }

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.state});

  final String label;
  final _Lamp state;

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (state) {
      _Lamp.checking => (Icons.hourglass_top, AppColors.muted, 'Đang kiểm tra'),
      _Lamp.up => (Icons.check_circle, AppColors.ok, 'Hoạt động'),
      _Lamp.down => (Icons.error, AppColors.danger, 'Không kết nối'),
    };
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
        if (state != _Lamp.checking) Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
