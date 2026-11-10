import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Phone readiness for reliable alarms (plan §9, "Kiểm tra độ sẵn sàng").
class AlarmReadiness {
  const AlarmReadiness({
    required this.notifications,
    required this.exactAlarms,
    required this.fullScreen,
    required this.batteryUnrestricted,
    required this.vietnameseVoice,
    this.microphone = false,
  });

  final bool notifications;
  final bool exactAlarms;
  final bool fullScreen;
  final bool batteryUnrestricted;
  final bool vietnameseVoice;

  /// Optional: only needed for answering by voice.
  final bool microphone;

  /// Everything an alarm needs to ring, speak and show over the lock screen.
  bool get alarmsReady => notifications && exactAlarms && fullScreen && batteryUnrestricted && vietnameseVoice;

  factory AlarmReadiness.fromMap(Map<Object?, Object?> m) => AlarmReadiness(
        notifications: m['notifications'] == true,
        exactAlarms: m['exactAlarms'] == true,
        fullScreen: m['fullScreen'] == true,
        batteryUnrestricted: m['batteryUnrestricted'] == true,
        vietnameseVoice: m['vietnameseVoice'] == true,
        microphone: m['microphone'] == true,
      );
}

/// Must match AlarmScheduler.SCHEDULE_ID_BASE in Java.
const scheduleIdBase = 100000000;

/// A schedule alarm's id encodes its minute, so the alarm screen can find which doses are due
/// from the id alone, even offline and after a reboot.
int alarmIdForMinute(DateTime localMinute) => scheduleIdBase + localMinute.millisecondsSinceEpoch ~/ 60000;

DateTime? minuteOfAlarmId(int id) =>
    id < scheduleIdBase ? null : DateTime.fromMillisecondsSinceEpoch((id - scheduleIdBase) * 60000);

class ScheduledAlarm {
  const ScheduledAlarm({required this.id, required this.at, required this.title, required this.speech});
  final int id;
  final DateTime at;
  final String title;
  final String speech;
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

  /// Replaces every medication-schedule alarm (ids >= [scheduleIdBase]) with [alarms] in one call;
  /// alarms no longer listed are cancelled. Snoozes keep ringing.
  static Future<int> replaceSchedule(List<ScheduledAlarm> alarms) async =>
      await _channel.invokeMethod<int>('replaceSchedule', {
        'alarms': [
          for (final a in alarms)
            {'id': a.id, 'triggerAtMillis': a.at.millisecondsSinceEpoch, 'title': a.title, 'speech': a.speech},
        ],
      }) ??
      0;

  /// Alarms currently armed on the phone (for the elder's readiness screen and for testing).
  static Future<List<({int id, DateTime at, String title})>> scheduled() async {
    final raw = await _channel.invokeMethod<List<Object?>>('scheduled') ?? const [];
    return [
      for (final m in raw.cast<Map<Object?, Object?>>())
        (
          id: m['id'] as int,
          at: DateTime.fromMillisecondsSinceEpoch((m['triggerAtMillis'] as num).toInt()),
          title: m['title'] as String,
        ),
    ]..sort((a, b) => a.at.compareTo(b.at));
  }

  /// Silences the ringing alarm (after the elder confirms or snoozes).
  static Future<void> stopRinging() => _channel.invokeMethod('stopRinging');

  /// True where the native alarm engine exists (Android). On iPhone the caregiver app works but there is
  /// no alarm engine (docs/IPHONE.md), so status questions answer "nothing ringing" instead of throwing.
  static bool get supported => defaultTargetPlatform == TargetPlatform.android;

  /// Id of the alarm ringing right now, or null. Asked on every navigation, so it must never throw.
  static Future<int?> ringingId() async {
    try {
      final id = await _channel.invokeMethod<int>('ringingId');
      return (id == null || id < 0) ? null : id;
    } on MissingPluginException {
      return null;
    }
  }

  /// Every alarm ringing now (a new one joins an unanswered one), oldest first.
  static Future<List<int>> ringingIds() async {
    try {
      return (await _channel.invokeMethod<List<Object?>>('ringingIds') ?? const []).cast<int>();
    } on MissingPluginException {
      return const [];
    }
  }

  /// Says [text] once in Vietnamese on the alarm stream; silent if the phone has no Vietnamese voice.
  /// Elder phones only: re-sync the schedule every few hours in the background (no-op elsewhere).
  static Future<void> setBackgroundSync(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('backgroundSync', {'enabled': enabled});
    } on MissingPluginException {
      // Tests and non-Android platforms.
    }
  }

  static Future<void> speak(String text) => _channel.invokeMethod('speak', {'text': text});

  static Future<void> stopSpeaking() => _channel.invokeMethod('stopSpeaking');

  /// Pauses the ringing alarm's voice while the elder answers by voice (vibration continues).
  static Future<void> holdSpeech(Duration d) => _channel.invokeMethod('holdSpeech', {'ms': d.inMilliseconds});

  static Future<AlarmReadiness> readiness() async =>
      AlarmReadiness.fromMap(await _channel.invokeMethod<Map<Object?, Object?>>('readiness') ?? const {});

  static Future<void> requestNotificationPermission() => _channel.invokeMethod('requestNotificationPermission');

  /// which: notifications | exactAlarms | fullScreen | battery | tts | microphone
  static Future<void> openSettings(String which) => _channel.invokeMethod('openSettings', {'which': which});

  /// Called when an alarm starts ringing while the app is already open.
  static void onRinging(void Function(int id) handler, {void Function()? onSyncRequested}) {
    if (!supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'alarmRinging' && call.arguments is int) handler(call.arguments as int);
      // The periodic background sync fired while the app is open: refresh here instead of a second engine.
      if (call.method == 'syncNow') onSyncRequested?.call();
    });
  }
}
