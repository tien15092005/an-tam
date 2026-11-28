import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Sample of the elder theme (large text, 72dp buttons) so the team can check sizes on real devices.
class ElderPreviewScreen extends StatelessWidget {
  const ElderPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.build(UiDensity.elder),
      child: Builder(builder: (context) {
        final text = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(title: const Text('Xem thử: người già')),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Chào buổi sáng,', style: text.bodyLarge),
              Text('Bà Lan', style: text.headlineMedium),
              const SizedBox(height: AppSpacing.lg),
              Card(
                color: AppColors.primary,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lần uống tiếp theo', style: text.bodyLarge?.copyWith(color: AppColors.onAccent)),
                      Text('07:30', style: text.headlineMedium?.copyWith(color: AppColors.onAccent)),
                      Text('Amlodipin 5mg · 1 viên', style: text.titleMedium?.copyWith(color: AppColors.onAccent)),
                      Text('Viên tròn nhỏ màu trắng', style: text.bodyLarge?.copyWith(color: AppColors.onAccent)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.ok),
                onPressed: () {},
                icon: const Icon(Icons.check_circle, size: 32),
                label: const Text('ĐÃ UỐNG RỒI'),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: () {}, child: const Text('Nhắc lại sau 10 phút')),
            ],
          ),
        );
      }),
    );
  }
}
