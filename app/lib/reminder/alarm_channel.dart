import 'package:flutter/services.dart';

/// Phone readiness for reliable alarms (plan §9, "Kiểm tra độ sẵn sàng").
class AlarmReadiness {
  const AlarmReadiness({
    required this.notifications,
    required this.exactAlarms,
    required this.fullScreen,
    required this.batteryUnrestricted,
    required this.vietnameseVoice,
  });

  final bool notifications;
  final bool exactAlarms;
  final bool fullScreen;
  final bool batteryUnrestricted;
  final bool vietnameseVoice;

  factory AlarmReadiness.fromMap(Map<Object?, Object?> m) => AlarmReadiness(
        notifications: m['notifications'] == true,
        exactAlarms: m['exactAlarms'] == true,
        fullScreen: m['fullScreen'] == true,
        batteryUnrestricted: m['batteryUnrestricted'] == true,
        vietnameseVoice: m['vietnameseVoice'] == true,
      );
}

/// Dart side of the native (Java) alarm engine. Alarms ring from Android itself,
/// so they work with the app closed, offline, and after a reboot.
class AlarmChannel {
  AlarmChannel._();

  static const _channel = MethodChannel('vn.antam/alarm');

  static Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String speech,
  }) =>
      _channel.invokeMethod('schedule', {
        'id': id,
        'triggerAtMillis': at.millisecondsSinceEpoch,
        'title': title,
        'speech': speech,
      });

  static Future<void> cancel(int id) => _channel.invokeMethod('cancel', {'id': id});

  /// Silences the ringing alarm (after the elder confirms or snoozes).
  static Future<void> stopRinging() => _channel.invokeMethod('stopRinging');

  /// Id of the alarm ringing right now, or null.
  static Future<int?> ringingId() async {
    final id = await _channel.invokeMethod<int>('ringingId');
    return (id == null || id < 0) ? null : id;
  }

  static Future<AlarmReadiness> readiness() async =>
      AlarmReadiness.fromMap(await _channel.invokeMethod<Map<Object?, Object?>>('readiness') ?? const {});

  static Future<void> requestNotificationPermission() => _channel.invokeMethod('requestNotificationPermission');

  /// which: notifications | exactAlarms | fullScreen | battery | tts
  static Future<void> openSettings(String which) => _channel.invokeMethod('openSettings', {'which': which});

  /// Called when an alarm starts ringing while the app is already open.
  static void onRinging(void Function(int id) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'alarmRinging' && call.arguments is int) handler(call.arguments as int);
    });
  }
}
