import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../reminder/alarm_channel.dart';
import 'session.dart';

/// The elder types the 6-digit code their child created. Large digits, one action.
class ElderPairScreen extends ConsumerStatefulWidget {
  const ElderPairScreen({super.key});

  @override
  ConsumerState<ElderPairScreen> createState() => _ElderPairScreenState();
}

class _ElderPairScreenState extends ConsumerState<ElderPairScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).pairElder(_code.text);
    } catch (e) {
      setState(() => _error = describeNetworkError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.build(UiDensity.elder),
      child: Builder(builder: (context) {
        final text = Theme.of(context).textTheme;
        if (!AlarmChannel.supported) {
          // iPhone cannot keep ringing and reading aloud until the elder answers (docs/IPHONE.md).
          return Scaffold(
            appBar: AppBar(title: const Text('Máy của bố mẹ')),
            body: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
              Text('Máy của bố mẹ cần là điện thoại Android.', style: text.titleLarge),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Trên iPhone, ứng dụng không thể đổ chuông và đọc tên thuốc liên tục khi đã đóng. '
                'Các con vẫn dùng iPhone bình thường để theo dõi và đặt lịch.',
                style: text.bodyLarge,
              ),
            ]),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Nhập mã của con')),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Con đã gửi cho bạn một mã gồm 6 chữ số.', style: text.bodyLarge),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                key: const Key('pairCode'),
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: 14),
                decoration: const InputDecoration(counterText: '', hintText: '••••••'),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _code.text.length == 6 ? _submit() : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: text.bodyLarge?.copyWith(color: AppColors.danger)),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _busy || _code.text.length != 6 ? null : _submit,
                child: _busy ? CircularProgressIndicator(color: AppColors.onAccent) : const Text('Vào ứng dụng'),
              ),
            ],
          ),
        );
      }),
    );
  }
}
