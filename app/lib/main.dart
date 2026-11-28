import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/server_config.dart';
import 'features/auth/session.dart';
import 'reminder/alarm_channel.dart';
import 'reminder/schedule_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const AnTamApp(),
  ));
}

/// Started by Android every few hours on elder phones (BackgroundSync.java), with no screen: download the
/// schedule, send queued answers, re-arm the next 7 days of alarms. Then tell the native side it is done.
@pragma('vm:entry-point')
Future<void> backgroundSync() async {
  WidgetsFlutterBinding.ensureInitialized();
  const done = MethodChannel('vn.antam/background');
  ProviderContainer? container;
  try {
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    final session = await container.read(sessionProvider.future);
    if (session == null) {
      debugPrint('background sync: not signed in');
    } else {
      await container.read(elderScheduleProvider.future);
      await container.read(elderScheduleProvider.notifier).refresh();
      final s = container.read(elderScheduleProvider).value;
      debugPrint('background sync: ${s?.meds.length ?? 0} medicines, offline=${s?.offline}, '
          '${(await AlarmChannel.scheduled()).length} alarms armed');
    }
  } catch (e) {
    debugPrint('background sync failed: $e');
  } finally {
    container?.dispose();
    await done.invokeMethod<void>('done');
  }
}
