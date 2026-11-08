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
    private static final String CHANNEL = "vn.antam/alarm";
    private static final int REQUEST_NOTIFICATIONS = 1;

    private MethodChannel channel;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        showOverLockScreenIfRinging(getIntent());
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        showOverLockScreenIfRinging(intent);
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
        channel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "schedule": {
                    Integer id = call.argument("id");
                    Number at = call.argument("triggerAtMillis");
                    String title = call.argument("title");
                    String speech = call.argument("speech");
                    if (id == null || at == null || title == null || speech == null) {
                        result.error("bad_args", "id, triggerAtMillis, title, speech are required", null);
                        return;
                    }
                    AlarmScheduler.schedule(this, id, at.longValue(), title, speech);
                    result.success(null);
                    break;
                }
                case "cancel": {
                    Integer id = call.argument("id");
                    if (id != null) AlarmScheduler.cancel(this, id);
                    result.success(null);
                    break;
                }
                case "stopRinging":
                    AlarmService.stop(this);
                    clearLockScreenFlags();
                    result.success(null);
                    break;
                case "ringingId":
                    result.success(AlarmScheduler.ringingId(this));
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

    private void openSettings(String which) {
        Intent intent;
        Uri pkg = Uri.parse("package:" + getPackageName());
        if ("fullScreen".equals(which) && Build.VERSION.SDK_INT >= 34) {
            intent = new Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, pkg);
        } else if ("exactAlarms".equals(which) && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            intent = new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkg);
        } else if ("battery".equals(which)) {
            intent = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
        } else if ("tts".equals(which)) {
            intent = new Intent("com.android.settings.TTS_SETTINGS");
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
