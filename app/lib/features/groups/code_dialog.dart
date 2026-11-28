import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens.dart';
import 'groups_api.dart';

/// Shows a pairing or invite code large enough to read aloud over the phone, with a copy button.
Future<void> showCodeDialog(BuildContext context, {required String title, required String hint, required CodeResult code}) {
  final t = TimeOfDay.fromDateTime(code.expiresAt).format(context);
  final d = code.expiresAt;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            code.code,
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 6, color: AppColors.navy),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Hết hạn lúc $t ngày ${d.day}/${d.month}'),
          const SizedBox(height: AppSpacing.sm),
          Text(hint, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code.code));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép mã')));
            }
          },
          child: const Text('Sao chép'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Xong')),
      ],
    ),
  );
}

/// Simple yes/no confirmation; returns true when confirmed.
Future<bool> confirm(BuildContext context, {required String title, required String message, required String action}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    ) ??
    false;

/// Asks for one line of text; returns null if cancelled.
Future<String?> promptText(BuildContext context,
    {required String title, required String label, String action = 'Lưu', TextCapitalization caps = TextCapitalization.sentences}) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, textCapitalization: caps, decoration: InputDecoration(labelText: label)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text.trim().isEmpty ? null : c.text.trim()),
          child: Text(action),
        ),
      ],
    ),
  );
}
