import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';
import 'session.dart';

/// Caregiver sign-in and registration on one screen.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _register = false;
  bool _busy = false;
  String? _error;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = ref.read(sessionProvider.notifier);
    try {
      if (_register) {
        if (_password.text.length < 8) throw const _LocalError('Mật khẩu cần ít nhất 8 ký tự.');
        await session.register(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _name.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        );
      } else {
        await session.login(_email.text.trim(), _password.text);
      }
      // The router leaves this screen once the session is set.
    } on _LocalError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = describeNetworkError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_register ? 'Tạo tài khoản người con' : 'Đăng nhập')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Đăng nhập')),
              ButtonSegment(value: true, label: Text('Đăng ký')),
            ],
            selected: {_register},
            onSelectionChanged: (s) => setState(() {
              _register = s.first;
              _error = null;
            }),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_register) ...[
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Họ tên')),
            const SizedBox(height: AppSpacing.md),
          ],
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_register) ...[
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại', helperText: 'Để bố mẹ bấm gọi cho bạn'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(labelText: 'Mật khẩu', helperText: _register ? 'Ít nhất 8 ký tự' : null),
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
                : Text(_register ? 'Tạo tài khoản' : 'Đăng nhập'),
          ),
        ],
      ),
    );
  }
}

class _LocalError implements Exception {
  const _LocalError(this.message);
  final String message;
}
