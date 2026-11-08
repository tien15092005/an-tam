import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';

/// First screen: the elder's phone and the caregiver's phone take different paths.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const SizedBox(height: AppSpacing.xl),
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: const Icon(Icons.favorite, color: Colors.white, size: 40),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('An Tâm', style: text.headlineMedium),
            Text('Nhắc bố mẹ uống thuốc, cả nhà cùng yên tâm', style: text.bodyMedium),
            const SizedBox(height: AppSpacing.xl),
            _RoleCard(
              icon: Icons.elderly,
              title: 'Tôi là bố / mẹ',
              subtitle: 'Nhập mã 6 số con gửi',
              color: AppColors.primary,
              background: AppColors.primarySoft,
              onTap: () => context.push('/pair'),
            ),
            const SizedBox(height: AppSpacing.md),
            _RoleCard(
              icon: Icons.family_restroom,
              title: 'Tôi là người con',
              subtitle: 'Đăng nhập để chăm sóc bố mẹ cùng anh chị em',
              color: AppColors.navy,
              background: AppColors.navySoft,
              onTap: () => context.push('/login'),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextButton(onPressed: () => context.push('/connection'), child: const Text('Cài đặt máy chủ')),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(title, style: text.titleMedium), Text(subtitle, style: text.bodyMedium)],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
