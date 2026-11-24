import 'package:flutter/material.dart';

import 'tokens.dart';

/// A small grey section title in capitals ("BỐ MẸ", "CẦN BẠN XEM").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color, this.trailing});
  final String text;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
        child: Row(children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color ?? AppColors.muted, letterSpacing: 0.4)),
          ),
          ?trailing,
        ]),
      );
}

/// Round initial for a person ("L" for Bà Lan).
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(this.name, {super.key, this.size = 40, this.strong = false});
  final String name;
  final double size;
  final bool strong;

  static String initialOf(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    final last = words.isEmpty ? '' : words.last;
    return last.isEmpty ? '?' : last.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: strong ? AppColors.primary : AppColors.primarySoft, shape: BoxShape.circle),
        child: Text(initialOf(name),
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: size * 0.42,
                color: strong ? AppColors.onAccent : AppColors.primary)),
      );
}
