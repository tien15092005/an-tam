import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';

class AlertItem {
  const AlertItem({
    required this.id,
    required this.elderName,
    required this.kind,
    this.medicationNames,
    this.scheduledTime,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedByName,
  });

  final int id;
  final String elderName;
  final String kind;
  final String? medicationNames;
  final String? scheduledTime;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedByName;

  factory AlertItem.fromJson(Map<String, dynamic> j) => AlertItem(
        id: j['id'] as int,
        elderName: j['elderName'] as String? ?? '',
        kind: j['kind'] as String,
        medicationNames: j['medicationNames'] as String?,
        scheduledTime: j['scheduledTime'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        resolvedAt: j['resolvedAt'] == null ? null : DateTime.parse(j['resolvedAt'] as String).toLocal(),
        resolvedByName: j['resolvedByName'] as String?,
      );

  /// "Bà Lan báo mất thuốc Amlodipin (liều 08:00)"
  String get sentence {
    final what = switch (kind) {
      'LOST_MEDICINE' => 'báo mất thuốc',
      'OUT_OF_MEDICINE' => 'báo hết thuốc',
      'UNSURE_PILL' => 'không chắc thuốc có đúng không',
      'UNWELL' => 'báo đang thấy không khỏe',
      'OTHER_ISSUE' => 'báo có vấn đề khác',
      'NOT_CONFIRMED' => 'chưa xác nhận uống thuốc',
      _ => 'có cảnh báo',
    };
    final med = medicationNames == null ? '' : ' $medicationNames';
    final time = scheduledTime == null ? '' : ' (liều $scheduledTime)';
    return '$elderName $what$med$time';
  }

  IconData get icon => switch (kind) {
        'UNWELL' => Icons.sick,
        'LOST_MEDICINE' => Icons.search_off,
        'OUT_OF_MEDICINE' => Icons.remove_shopping_cart,
        'UNSURE_PILL' => Icons.help_outline,
        _ => Icons.report,
      };
}

class DoseLogItem {
  const DoseLogItem(this.name, this.dosage, this.time, this.status, this.checkResult, this.loggedAt);
  final String name;
  final String? dosage;
  final String time;
  final String status;
  final String? checkResult;
  final DateTime loggedAt;

  factory DoseLogItem.fromJson(Map<String, dynamic> j) => DoseLogItem(
        j['name'] as String,
        j['dosage'] as String?,
        j['scheduledTime'] as String,
        j['status'] as String,
        j['checkResult'] as String?,
        DateTime.parse(j['loggedAt'] as String).toLocal(),
      );

  (String, Color) get look => switch (status) {
        'TAKEN' => ('Đã uống', AppColors.ok),
        'NOT_TAKEN' => ('Không uống được', AppColors.warn),
        _ => ('Bỏ qua', AppColors.muted),
      };
}

final openAlertsProvider = FutureProvider.autoDispose.family<List<AlertItem>, int>((ref, groupId) async {
  final r = await ref.read(dioProvider).get<List<dynamic>>('/api/groups/$groupId/alerts');
  return r.data!.map((j) => AlertItem.fromJson(j as Map<String, dynamic>)).toList();
});

typedef ElderDay = ({int groupId, int elderUserId, String date});

final doseLogsProvider = FutureProvider.autoDispose.family<List<DoseLogItem>, ElderDay>((ref, k) async {
  final r = await ref
      .read(dioProvider)
      .get<List<dynamic>>('/api/groups/${k.groupId}/elders/${k.elderUserId}/doses', queryParameters: {'date': k.date});
  return r.data!.map((j) => DoseLogItem.fromJson(j as Map<String, dynamic>)).toList();
});

Future<void> resolveAlert(WidgetRef ref, int groupId, int alertId) async {
  await ref.read(dioProvider).post<void>('/api/groups/$groupId/alerts/$alertId/resolve');
  ref.invalidate(openAlertsProvider(groupId));
}

String hhmmOf(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Open alerts in red at the top of a group, each resolvable by any caregiver.
class OpenAlertsSection extends ConsumerWidget {
  const OpenAlertsSection({super.key, required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final alerts = ref.watch(openAlertsProvider(groupId)).value ?? const [];
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Cảnh báo cần xem (${alerts.length})', style: text.titleMedium?.copyWith(color: AppColors.danger)),
      const SizedBox(height: AppSpacing.sm),
      for (final a in alerts)
        Card(
          color: AppColors.dangerSoft,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(children: [
              Icon(a.icon, color: AppColors.danger, size: 32),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.sentence, style: text.titleSmall),
                  Text('Lúc ${hhmmOf(a.createdAt)} ngày ${a.createdAt.day}/${a.createdAt.month}', style: text.bodySmall),
                ]),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await resolveAlert(ref, groupId, a.id);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeNetworkError(e))));
                    }
                  }
                },
                child: const Text('Đã xử lý'),
              ),
            ]),
          ),
        ),
      const SizedBox(height: AppSpacing.md),
    ]);
  }
}
