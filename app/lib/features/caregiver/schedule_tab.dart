import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/section_label.dart';
import '../../core/theme/tokens.dart';
import '../care/care_api.dart';
import '../exercises/exercise_form_screen.dart';
import '../exercises/exercises_api.dart';
import '../groups/code_dialog.dart' show confirm;
import '../groups/groups_api.dart';
import '../medications/med_photo.dart';
import '../medications/medication_form_screen.dart';
import '../medications/medications_api.dart';
import '../medications/medications_screen.dart' show scheduleSummary;
import '../ocr/ocr_scan_screen.dart';
import 'today_api.dart';
import 'today_tab.dart';

part 'schedule_parts.dart';

const _months = [
  '',
  'Tháng 1',
  'Tháng 2',
  'Tháng 3',
  'Tháng 4',
  'Tháng 5',
  'Tháng 6',
  'Tháng 7',
  'Tháng 8',
  'Tháng 9',
  'Tháng 10',
  'Tháng 11',
  'Tháng 12',
];
const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

DateTime get _today {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Morning, noon, afternoon, evening: how families talk about medicine times.
String sessionOf(String hhmm) {
  final h = int.tryParse(hhmm.split(':').first) ?? 0;
  if (h < 11) return 'Sáng';
  if (h < 14) return 'Trưa';
  if (h < 18) return 'Chiều';
  return 'Tối';
}

/// "Thuốc" (plan §10): this week at a glance, every medicine by time of day, and one "+ Thêm" button
/// (scan a prescription, type it in, or an exercise). Only the one who sets medicines can add or edit.
class ScheduleTab extends ConsumerStatefulWidget {
  const ScheduleTab({super.key, required this.group, required this.elderUserId, required this.onElderChanged});

  final GroupDetail group;
  final int? elderUserId;
  final ValueChanged<int> onElderChanged;

  @override
  ConsumerState<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends ConsumerState<ScheduleTab> {
  ElderRef? get _elder => widget.elderUserId == null ? null : (groupId: widget.group.id, elderUserId: widget.elderUserId!);

  void _reload() {
    ref.invalidate(calendarProvider);
    ref.invalidate(dayViewProvider);
    final e = _elder;
    if (e != null) {
      ref.invalidate(exercisesProvider(e));
      ref.invalidate(medicationsProvider(e));
    }
  }

  Future<void> _push(Widget screen) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (changed == true) _reload();
  }

  Future<void> _editMedication({Medication? existing, DateTime? start}) => _push(
    MedicationFormScreen(groupId: widget.group.id, elderUserId: widget.elderUserId!, existing: existing, startDate: start),
  );

  Future<void> _editExercise({Exercise? existing, DateTime? start}) =>
      _push(ExerciseFormScreen(groupId: widget.group.id, elderUserId: widget.elderUserId!, existing: existing, startDate: start));

  Future<void> _deleteExercise(Exercise e) async {
    if (!await confirm(context, title: 'Xóa lịch tập?', message: 'Máy của bố mẹ sẽ thôi nhắc "${e.title}".', action: 'Xóa')) {
      return;
    }
    try {
      await ref.read(exercisesApiProvider).delete(widget.group.id, e.id);
      _reload();
    } catch (err) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeNetworkError(err))));
    }
  }

  /// "+ Thêm": three big choices, the prescription scan first since it saves the most typing.
  Future<void> _add(String elderName, {DateTime? start}) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Thêm cho $elderName', style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              _AddChoice(
                key: const Key('addScan'),
                strong: true,
                icon: Icons.document_scanner_outlined,
                title: 'Chụp toa thuốc',
                subtitle: 'Hoặc vỏ hộp, hóa đơn. App tự điền, bạn kiểm tra lại.',
                onTap: () => Navigator.pop(sheet, 'scan'),
              ),
              _AddChoice(
                key: const Key('addMedication'),
                icon: Icons.edit_outlined,
                title: 'Nhập tay',
                subtitle: 'Tên thuốc, liều, giờ uống',
                onTap: () => Navigator.pop(sheet, 'manual'),
              ),
              _AddChoice(
                key: const Key('addExercise'),
                icon: Icons.directions_walk,
                iconColor: AppColors.ok,
                iconBackground: AppColors.okSoft,
                title: 'Lịch tập thể dục',
                subtitle: 'Đi bộ, tập tay... theo thứ trong tuần',
                onTap: () => Navigator.pop(sheet, 'exercise'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'scan':
        await _push(OcrScanScreen(groupId: widget.group.id, elderUserId: widget.elderUserId!, startDate: start));
      case 'manual':
        await _editMedication(start: start);
      case 'exercise':
        await _editExercise(start: start);
    }
  }

  void _openDay(DateTime day, String elderName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _DaySheet(
          group: widget.group,
          elderUserId: widget.elderUserId!,
          day: day,
          onAdd: () => _add(elderName, start: day),
          onChanged: _reload,
        ),
      ),
    );
  }

  void _openMonth(ElderRef elder, String elderName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => FractionallySizedBox(
        heightFactor: 0.8,
        child: _MonthSheet(
          elder: elder,
          onTap: (d) {
            Navigator.pop(sheet);
            _openDay(d, elderName);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final elders = widget.group.members.where((m) => m.role == GroupRole.elder).toList();
    final owner = widget.group.iAmOwner;
    final elder = _elder;
    final elderName = elders.where((e) => e.userId == widget.elderUserId).firstOrNull?.displayName ?? 'bố mẹ';

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: owner && elder != null
          ? FloatingActionButton.extended(
              key: const Key('addAny'),
              onPressed: () => _add(elderName),
              icon: const Icon(Icons.add),
              label: const Text('Thêm'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
          children: [
            Text(elder == null ? 'Thuốc' : 'Thuốc của $elderName', style: text.headlineSmall?.copyWith(fontSize: 24)),
            if (elders.length > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final e in elders)
                    ChoiceChip(
                      label: Text(e.displayName),
                      selected: e.userId == widget.elderUserId,
                      onSelected: (_) => widget.onElderChanged(e.userId),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (elder == null)
              const Text('Chưa có hồ sơ bố mẹ. Vào tab "Gia đình" để thêm.')
            else ...[
              _WeekStrip(elder: elder, onTap: (d) => _openDay(d, elderName)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: () => _openMonth(elder, elderName), child: const Text('Xem cả tháng')),
              ),
              if (!owner)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    'Bạn xem được lịch và nhận báo cáo. Người đặt lịch thuốc trong gia đình mới thêm, sửa được.',
                    style: text.bodySmall,
                  ),
                ),
              _MedicinesBySession(
                elder: elder,
                owner: owner,
                onEdit: (m) => _editMedication(existing: m),
              ),
              ref
                  .watch(exercisesProvider(elder))
                  .when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => Text(describeNetworkError(e)),
                    data: (list) => list.isEmpty
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: AppSpacing.sm),
                              const SectionLabel('Tập thể dục'),
                              Card(
                                child: Column(
                                  children: [
                                    for (final e in list)
                                      ListTile(
                                        leading: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: AppColors.okSoft,
                                            borderRadius: BorderRadius.circular(AppRadius.sm),
                                          ),
                                          child: Icon(Icons.directions_walk, color: AppColors.ok),
                                        ),
                                        title: Text(e.title),
                                        subtitle: Text(
                                          [
                                            e.time,
                                            weekdaysLabel(e.daysOfWeek),
                                            if (e.durationMin != null) '${e.durationMin} phút',
                                          ].join(' · '),
                                        ),
                                        trailing: owner
                                            ? PopupMenuButton<String>(
                                                onSelected: (v) => v == 'edit' ? _editExercise(existing: e) : _deleteExercise(e),
                                                itemBuilder: (_) => const [
                                                  PopupMenuItem(value: 'edit', child: Text('Sửa')),
                                                  PopupMenuItem(value: 'delete', child: Text('Xóa')),
                                                ],
                                              )
                                            : null,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
