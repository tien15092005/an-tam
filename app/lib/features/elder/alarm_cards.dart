part of 'alarm_screen.dart';

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.minute, required this.exercise, this.onGo});

  final DateTime minute;
  final ElderExercise exercise;

  /// Shown only when medicines ring at the same minute (the big button handles exercise-only alarms).
  final VoidCallback? onGo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hhmm = '${minute.hour.toString().padLeft(2, '0')}:${minute.minute.toString().padLeft(2, '0')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Icon(Icons.directions_walk, size: 96, color: AppColors.ok, semanticLabel: 'Tập thể dục'),
              Text(exercise.title, style: text.headlineSmall, textAlign: TextAlign.center),
              if (exercise.durationMin != null) Text('${exercise.durationMin} phút', style: text.titleMedium),
              if (exercise.note != null) Text(exercise.note!, style: text.bodyLarge, textAlign: TextAlign.center),
              Text('Giờ tập $hhmm', style: text.bodyLarge?.copyWith(color: AppColors.muted)),
              if (onGo != null) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: onGo,
                  icon: const Icon(Icons.directions_walk),
                  label: const Text('Tôi đi tập đây'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MedCard extends StatelessWidget {
  const _MedCard({required this.minute, required this.med});

  final DateTime minute;
  final ElderMed med;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hhmm = '${minute.hour.toString().padLeft(2, '0')}:${minute.minute.toString().padLeft(2, '0')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, box) {
            final photo = (box.maxWidth * 0.6).clamp(120.0, 200.0);
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Semantics(
                    label: 'Ảnh thuốc ${med.name}',
                    image: true,
                    child: med.photos.isEmpty ? NoMedPhoto(size: photo) : LocalMedPhoto(path: med.photos.first, size: photo),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(med.name, style: text.headlineSmall, textAlign: TextAlign.center),
                  if (med.dosage != null) Text(med.dosage!, style: text.titleMedium, textAlign: TextAlign.center),
                  if (med.description.isNotEmpty) Text(med.description, style: text.bodyLarge, textAlign: TextAlign.center),
                  if (med.note != null)
                    Text(
                      med.note!,
                      style: text.bodyLarge?.copyWith(color: AppColors.muted),
                      textAlign: TextAlign.center,
                    ),
                  Text('Giờ uống $hhmm', style: text.bodyLarge?.copyWith(color: AppColors.muted)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
