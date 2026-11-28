package vn.antam.app;

import android.Manifest;
import android.app.KeyguardManager;
import android.app.NotificationManager;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.speech.tts.TextToSpeech;
import android.view.WindowManager;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import vn.antam.app.alarm.AlarmScheduler;
import vn.antam.app.alarm.AlarmService;

/** Hosts Flutter and exposes the native alarm engine on the "vn.antam/alarm" channel. */
public class MainActivity extends FlutterActivity {

    public static final String EXTRA_OPEN_ALARM = "open_alarm";
    private static final String CHANNEL = vn.antam.app.alarm.AlarmChannelCore.CHANNEL;
    private static final int REQUEST_NOTIFICATIONS = 1;

    private MethodChannel channel;

    /** Voice for the "any problem?" question and "read it to me" on the home screen (not the alarm loop). */
    private TextToSpeech voice;
    private boolean voiceReady;
    private String pendingSpeech;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        showOverLockScreenIfRinging(getIntent());
        debugRunSync(getIntent());
    }

    /** Debug builds only: `adb shell am start -n vn.antam.app/.MainActivity --ez debugRunSync true` runs the
     *  background sync's headless engine once, to test it without waiting hours. */
    private void debugRunSync(Intent intent) {
        boolean debuggable = (getApplicationInfo().flags & android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0;
        if (!debuggable || intent == null) return;
        if (intent.getBooleanExtra("debugRunSync", false)) {
            vn.antam.app.sync.BackgroundSync.runNowForDebug(getApplicationContext());
        }
        int minutes = intent.getIntExtra("debugSyncIntervalMin", 0);
        if (minutes > 0) vn.antam.app.sync.BackgroundSync.setIntervalForDebug(getApplicationContext(), minutes * 60_000L);
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        showOverLockScreenIfRinging(intent);
        debugRunSync(intent);
        if (channel != null && AlarmScheduler.ringingId(this) >= 0) {
            channel.invokeMethod("alarmRinging", AlarmScheduler.ringingId(this));
        }
    }

    /** When opened by the alarm's full-screen intent, appear above the lock screen and wake the display. */
    private void showOverLockScreenIfRinging(Intent intent) {
        boolean fromAlarm = intent != null && intent.hasExtra(EXTRA_OPEN_ALARM);
        if (!fromAlarm && AlarmScheduler.ringingId(this) < 0) return;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true);
            setTurnScreenOn(true);
            KeyguardManager km = getSystemService(KeyguardManager.class);
            if (km != null) km.requestDismissKeyguard(this, null);
        } else {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);
        }
    }

    private void clearLockScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(false);
            setTurnScreenOn(false);
        } else {
            getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);
        }
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        channel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        live = this;
        channel.setMethodCallHandler((call, result) -> {
            // Scheduling and background sync live in AlarmChannelCore (shared with the headless sync engine).
            if (vn.antam.app.alarm.AlarmChannelCore.handle(this, call, result)) return;
            switch (call.method) {
                case "stopRinging":
                    AlarmScheduler.clearRinging(this);
                    AlarmService.stop(this);
                    clearLockScreenFlags();
                    result.success(null);
                    break;
                case "ringingId":
                    result.success(AlarmScheduler.ringingId(this));
                    break;
                case "speak": {
                    String text = call.argument("text");
                    if (text != null) speakOnce(text);
                    result.success(null);
                    break;
                }
                case "holdSpeech": {
                    Number ms = call.argument("ms");
                    AlarmService.hold(this, ms == null ? 8000 : ms.longValue());
                    result.success(null);
                    break;
                }
                case "stopSpeaking":
                    if (voice != null) voice.stop();
                    result.success(null);
                    break;
                case "readiness":
                    readiness(result);
                    break;
                case "requestNotificationPermission":
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                            && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, REQUEST_NOTIFICATIONS);
                    }
                    result.success(null);
                    break;
                case "openSettings":
                    openSettings(call.argument("which"));
                    result.success(null);
                    break;
                default:
                    result.notImplemented();
            }
        });
    }

    /** What the elder's phone still needs for alarms to work; shown on the readiness screen. */
    private void readiness(MethodChannel.Result result) {
        Map<String, Object> r = new HashMap<>();
        NotificationManager nm = getSystemService(NotificationManager.class);
        r.put("notifications", nm != null && nm.areNotificationsEnabled());
        r.put("exactAlarms", AlarmScheduler.canScheduleExact(this));
        r.put("fullScreen", Build.VERSION.SDK_INT < 34 || (nm != null && nm.canUseFullScreenIntent()));
        android.os.PowerManager pm = getSystemService(android.os.PowerManager.class);
        r.put("batteryUnrestricted", pm != null && pm.isIgnoringBatteryOptimizations(getPackageName()));
        r.put("microphone", checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED);
        // Voice and fallback tone both play on the alarm stream: turned down, nothing is heard.
        android.media.AudioManager am = getSystemService(android.media.AudioManager.class);
        r.put("alarmVolume", am != null && !vn.antam.app.alarm.AlarmPolicy.volumeTooLow(
                am.getStreamVolume(android.media.AudioManager.STREAM_ALARM),
                am.getStreamMaxVolume(android.media.AudioManager.STREAM_ALARM)));
        // The voice can only be checked after the TTS engine has finished initialising, so answer in its callback.
        final TextToSpeech[] probe = new TextToSpeech[1];
        probe[0] = new TextToSpeech(this, status -> {
            boolean vi = status == TextToSpeech.SUCCESS
                    && probe[0].isLanguageAvailable(new Locale("vi", "VN")) >= TextToSpeech.LANG_AVAILABLE;
            probe[0].shutdown();
            r.put("vietnameseVoice", vi);
            runOnUiThread(() -> result.success(r));
        });
    }

    /** Speaks once on the alarm stream (audible even with media volume at 0); replaces anything still being said. */
    private void speakOnce(String text) {
        if (voice == null) {
            pendingSpeech = text;
            voice = new TextToSpeech(this, status -> {
                if (status != TextToSpeech.SUCCESS) return;
                int lang = voice.setLanguage(new Locale("vi", "VN"));
                // Never read Vietnamese with an English voice (plan §9); the screen still shows the text.
                voiceReady = lang != TextToSpeech.LANG_MISSING_DATA && lang != TextToSpeech.LANG_NOT_SUPPORTED;
                voice.setAudioAttributes(new android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build());
                voice.setSpeechRate(0.9f);
                if (pendingSpeech != null) speakOnce(pendingSpeech);
                pendingSpeech = null;
            });
            return;
        }
        if (!voiceReady) {
            pendingSpeech = text;
            return;
        }
        Bundle params = new Bundle();
        params.putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, android.media.AudioManager.STREAM_ALARM);
        voice.speak(text, TextToSpeech.QUEUE_FLUSH, params, "once-" + System.currentTimeMillis());
    }

    /** The activity whose engine is running, if any: a background sync then runs there (one engine owns the database). */
    private static volatile MainActivity live;

    /** @return true when the open app took the sync request. */
    public static boolean requestSyncInOpenApp() {
        MainActivity a = live;
        if (a == null || a.channel == null || a.isFinishing() || a.isDestroyed()) return false;
        a.runOnUiThread(() -> a.channel.invokeMethod("syncNow", null));
        return true;
    }

    @Override
    protected void onDestroy() {
        if (live == this) live = null;
        if (voice != null) voice.shutdown();
        super.onDestroy();
    }

    private void openSettings(String which) {
        if ("volume".equals(which)) {
            // No settings page needed: raise the alarm volume directly and show the system volume slider.
            android.media.AudioManager am = getSystemService(android.media.AudioManager.class);
            if (am != null) {
                int max = am.getStreamMaxVolume(android.media.AudioManager.STREAM_ALARM);
                try {
                    am.setStreamVolume(android.media.AudioManager.STREAM_ALARM, vn.antam.app.alarm.AlarmPolicy.raisedVolume(max),
                            android.media.AudioManager.FLAG_SHOW_UI);
                } catch (SecurityException e) {
                    // Do Not Disturb can forbid it; the slider below lets the family raise it by hand.
                    am.adjustStreamVolume(android.media.AudioManager.STREAM_ALARM, android.media.AudioManager.ADJUST_SAME,
                            android.media.AudioManager.FLAG_SHOW_UI);
                }
            }
            return;
        }
        Intent intent;
        Uri pkg = Uri.parse("package:" + getPackageName());
        if ("fullScreen".equals(which) && Build.VERSION.SDK_INT >= 34) {
            intent = new Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, pkg);
        } else if ("exactAlarms".equals(which) && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            intent = new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkg);
        } else if ("battery".equals(which)) {
            intent = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
        } else if ("microphone".equals(which)) {
            intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg);
        } else if ("tts".equals(which)) {
            intent = new Intent("com.android.settings.TTS_SETTINGS");
        } else if ("date".equals(which)) {
            intent = new Intent(Settings.ACTION_DATE_SETTINGS);
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            intent = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, getPackageName());
        } else {
            intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg);
        }
        try {
            startActivity(intent);
        } catch (Exception e) {
            startActivity(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg));
        }
    }
}
