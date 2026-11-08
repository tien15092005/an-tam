import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../reminder/alarm_channel.dart';

/// Phase 2 test bench: schedule alarms with hard-coded text and check the phone's readiness.
class AlarmSpikeScreen extends StatefulWidget {
  const AlarmSpikeScreen({super.key});

  @override
  State<AlarmSpikeScreen> createState() => _AlarmSpikeScreenState();
}

class _AlarmSpikeScreenState extends State<AlarmSpikeScreen> {
  static const _speech = 'Bà Lan ơi, đến giờ uống thuốc rồi ạ. Amlodipin, 1 viên. '
      'Viên tròn nhỏ màu trắng. Uống xong, bà bấm nút màu xanh.';

  AlarmReadiness? _readiness;
  final _log = <String>[];

  @override
  void initState() {
    super.initState();
    AlarmChannel.requestNotificationPermission();
    _refresh();
  }

  Future<void> _refresh() async {
    final r = await AlarmChannel.readiness();
    if (mounted) setState(() => _readiness = r);
  }

  Future<void> _scheduleIn(Duration d) async {
    final at = DateTime.now().add(d);
    final id = at.millisecondsSinceEpoch ~/ 1000 % 1000000;
    await AlarmChannel.schedule(id: id, at: at, title: 'Đến giờ uống thuốc', speech: _speech);
    setState(() => _log.insert(0, 'Đặt báo #$id lúc ${TimeOfDay.fromDateTime(at).format(context)}'));
  }

  @override
  Widget build(BuildContext context) {
    final r = _readiness;
    return Scaffold(
      appBar: AppBar(title: const Text('Thử nghiệm báo thức')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Kiểm tra độ sẵn sàng', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (r == null)
              const LinearProgressIndicator()
            else ...[
              _Check('Cho phép thông báo', r.notifications, () => AlarmChannel.openSettings('notifications')),
              _Check('Báo thức đúng giờ', r.exactAlarms, () => AlarmChannel.openSettings('exactAlarms')),
              _Check('Hiện trên màn hình khóa', r.fullScreen, () => AlarmChannel.openSettings('fullScreen')),
              _Check('Không bị tối ưu pin', r.batteryUnrestricted, () => AlarmChannel.openSettings('battery')),
              _Check('Có giọng đọc tiếng Việt', r.vietnameseVoice, () => AlarmChannel.openSettings('tts')),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: () => _scheduleIn(const Duration(seconds: 15)), child: const Text('Báo sau 15 giây')),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: () => _scheduleIn(const Duration(minutes: 1)), child: const Text('Báo sau 1 phút')),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: () => _scheduleIn(const Duration(minutes: 5)), child: const Text('Báo sau 5 phút')),
            const SizedBox(height: AppSpacing.md),
            for (final line in _log) Text(line, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check(this.label, this.ok, this.onFix);

  final String label;
  final bool ok;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(ok ? Icons.check_circle : Icons.error, color: ok ? AppColors.ok : AppColors.danger),
      title: Text(label),
      trailing: ok ? null : TextButton(onPressed: onFix, child: const Text('Sửa')),
    );
  }
}
