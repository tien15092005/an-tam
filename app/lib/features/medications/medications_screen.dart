import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';
import '../care/care_api.dart';
import '../groups/groups_api.dart';
import 'med_photo.dart';
import 'medication_form_screen.dart';
import 'medications_api.dart';

const weekdayShort = {1: 'T2', 2: 'T3', 3: 'T4', 4: 'T5', 5: 'T6', 6: 'T7', 7: 'CN'};

String scheduleSummary(Medication m) {
  final days = m.everyDay ? 'Hằng ngày' : m.daysOfWeek.map((d) => weekdayShort[d]).join(', ');
  final end = m.endDate == null ? '' : ' · đến ${m.endDate!.day}/${m.endDate!.month}';
  return '$days · ${m.times.join(', ')}$end';
}

/// An elder's medications. Everyone in the group sees them; only the owner adds, edits or deletes.
class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({super.key, required this.groupId, required this.elderUserId});

  final int groupId;
  final int elderUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (groupId: groupId, elderUserId: elderUserId);
    final meds = ref.watch(medicationsProvider(key));
    final group = ref.watch(groupDetailProvider(groupId)).value;
    final elder = group?.members.where((m) => m.userId == elderUserId).firstOrNull;
    final isOwner = group?.iAmOwner ?? false;
    final now = DateTime.now();
    final todayKey = (
      groupId: groupId,
      elderUserId: elderUserId,
      date: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );
    final logs = ref.watch(doseLogsProvider(todayKey)).value ?? const [];

    Future<void> openForm([Medication? m]) async {
      final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => MedicationFormScreen(groupId: groupId, elderUserId: elderUserId, existing: m),
      ));
      if (changed == true) ref.invalidate(medicationsProvider(key));
    }

    return Scaffold(
      appBar: AppBar(title: Text(elder == null ? 'Thuốc' : 'Thuốc của ${elder.displayName}')),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              key: const Key('addMedication'),
              onPressed: openForm,
              icon: const Icon(Icons.add),
              label: const Text('Thêm thuốc'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(doseLogsProvider(todayKey));
          ref.invalidate(medicationsProvider(key));
          await ref.read(medicationsProvider(key).future);
        },
        child: meds.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [Text(describeNetworkError(e))]),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
            children: [
              if (!isOwner && group != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text('Chỉ người đặt lịch thuốc trong gia đình mới thêm, sửa được. Bạn xem được lịch và nhận báo cáo.'),
                ),
              if (logs.isNotEmpty) ...[
                Text('Hôm nay bố mẹ đã báo', style: Theme.of(context).textTheme.titleMedium),
                for (final l in logs)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(l.status == 'TAKEN' ? Icons.check_circle : Icons.block, color: l.look.$2),
                    title: Text('${l.time} · ${l.name}'),
                    subtitle: Text('${l.look.$1} lúc ${hhmmOf(l.loggedAt)}'
                        '${l.checkResult == 'ISSUE' ? ' · có báo vấn đề' : l.checkResult == 'NO_RESPONSE' ? ' · không trả lời câu hỏi' : ''}'),
                  ),
                const Divider(),
              ],
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(isOwner ? 'Chưa có thuốc nào. Bấm "Thêm thuốc" để đặt lịch.' : 'Chưa có thuốc nào.',
                      textAlign: TextAlign.center),
                ),
              for (final m in list)
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(AppSpacing.sm),
                    leading: m.images.isEmpty ? const NoMedPhoto(size: 56) : RemoteMedPhoto(url: m.images.first.url, size: 56),
                    title: Text(m.title),
                    subtitle: Text([
                      if (m.dosage != null) m.dosage!,
                      scheduleSummary(m),
                      if (m.description.isNotEmpty) m.description,
                    ].join('\n')),
                    isThreeLine: true,
                    trailing: isOwner ? const Icon(Icons.edit_outlined) : null,
                    onTap: isOwner ? () => openForm(m) : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
