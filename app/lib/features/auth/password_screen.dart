import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';
import 'session.dart';

/// Two uses: change the password while signed in (needs the current one), or reset a forgotten one with the
/// one-time code a sibling created in their "Gia đình" tab. Either way the other phones are signed out.
class PasswordScreen extends ConsumerStatefulWidget {
  const PasswordScreen({super.key, required this.reset});

  /// True: "Quên mật khẩu" (email + code). False: "Đổi mật khẩu" (current password).
  final bool reset;

  @override
  ConsumerState<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends ConsumerState<PasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _code, _current, _next, _again]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_next.text.length < 8) return setState(() => _error = 'Mật khẩu mới cần ít nhất 8 ký tự.');
    if (_next.text != _again.text) return setState(() => _error = 'Hai lần nhập mật khẩu mới chưa giống nhau.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = ref.read(sessionProvider.notifier);
      if (widget.reset) {
        await session.resetPassword(_email.text.trim(), _code.text.trim(), _next.text);
      } else {
        await session.changePassword(_current.text, _next.text);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đổi mật khẩu. Các máy khác đã được đăng xuất.')));
      widget.reset ? context.go('/') : Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = switch (errorCode(e)) {
            'wrong_password' => 'Mật khẩu hiện tại không đúng.',
            'invalid_code' => 'Mã không đúng hoặc đã hết hạn. Nhờ anh chị em tạo mã mới.',
            'password_too_long' => 'Mật khẩu quá dài. Hãy dùng mật khẩu ngắn hơn.',
            _ => describeNetworkError(e),
          });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.reset ? 'Quên mật khẩu' : 'Đổi mật khẩu')),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        if (widget.reset) ...[
          Text(
            'Nhờ một anh chị em trong gia đình mở tab "Gia đình", bấm vào tên bạn và chọn "Tạo mã đặt lại mật khẩu". '
            'Mã dùng được 15 phút.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email của bạn'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Mã đặt lại (10 ký tự)'),
          ),
        ] else
          TextField(
            controller: _current,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
          ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _next,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: const InputDecoration(labelText: 'Mật khẩu mới', helperText: 'Ít nhất 8 ký tự'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _again,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu mới'),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, style: TextStyle(color: AppColors.danger)),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : const Text('Lưu mật khẩu mới'),
        ),
      ]),
    );
  }
}
