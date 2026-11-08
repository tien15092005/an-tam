package vn.antam.app.alarm;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.media.AudioAttributes;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.util.Log;

import java.util.Locale;

import vn.antam.app.MainActivity;

/**
 * Rings an alarm: shows a full-screen alarm notification, vibrates, and reads the reminder aloud
 * through the ALARM audio stream again and again until the user confirms or snoozes.
 * There is deliberately no limit on the number of repetitions (product decision, see SKILL_AN_TAM.md §9).
 */
public class AlarmService extends Service {

    static final String TAG = "AnTamAlarm";
    static final String CHANNEL_ID = "antam_alarm";
    static final int NOTIFICATION_ID = 4711;
    static final String ACTION_RING = "vn.antam.app.alarm.RING";
    static final String ACTION_STOP = "vn.antam.app.alarm.STOP";
    static final long PAUSE_BETWEEN_READS_MS = 20_000;

    /** True while this process is ringing. A stored "ringing" id without a live service is stale. */
    static volatile boolean running;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private TextToSpeech tts;
    private boolean ttsReady;
    private boolean vietnameseVoice;
    private String speech = "";
    private int alarmId = -1;
    private int readCount;
    private PowerManager.WakeLock wakeLock;
    private final Runnable speakAgain = this::speak;

    static void start(Context context, AlarmStore.Alarm alarm) {
        Intent intent = new Intent(context, AlarmService.class)
                .setAction(ACTION_RING)
                .putExtra(AlarmScheduler.EXTRA_ALARM_ID, alarm.id)
                .putExtra("title", alarm.title)
                .putExtra("speech", alarm.speech);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent);
        } else {
            context.startService(intent);
        }
    }

    public static void stop(Context context) {
        context.startService(new Intent(context, AlarmService.class).setAction(ACTION_STOP));
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) return START_NOT_STICKY;
        if (ACTION_STOP.equals(intent.getAction())) {
            stopRinging();
            return START_NOT_STICKY;
        }
        alarmId = intent.getIntExtra(AlarmScheduler.EXTRA_ALARM_ID, -1);
        String title = intent.getStringExtra("title");
        speech = intent.getStringExtra("speech");
        startInForeground(buildNotification(title == null ? "Đến giờ uống thuốc" : title));
        running = true;
        AlarmStore.setRinging(this, alarmId);
        bringAlarmScreenToFront();
        acquireWakeLock();
        startVibration();
        startSpeaking();
        Log.i(TAG, "ringing alarm " + alarmId);
        return START_REDELIVER_INTENT;
    }

    private void startInForeground(Notification notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
        } else {
            startForeground(NOTIFICATION_ID, notification);
        }
    }

    private Notification buildNotification(String title) {
        NotificationManager nm = getSystemService(NotificationManager.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && nm.getNotificationChannel(CHANNEL_ID) == null) {
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, "Báo giờ uống thuốc", NotificationManager.IMPORTANCE_HIGH);
            channel.setDescription("Báo thức nhắc uống thuốc và tập thể dục");
            channel.setSound(null, null); // Sound comes from the spoken reminder on the alarm stream.
            channel.enableVibration(false); // Vibration is driven by the service so it repeats.
            channel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            nm.createNotificationChannel(channel);
        }
        Intent open = new Intent(this, MainActivity.class)
                .putExtra(MainActivity.EXTRA_OPEN_ALARM, alarmId)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent fullScreen = PendingIntent.getActivity(this, alarmId, open,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        Notification.Builder b = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? new Notification.Builder(this, CHANNEL_ID)
                : new Notification.Builder(this);
        b.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle(title)
                .setContentText("Mở app để xác nhận đã uống thuốc")
                .setCategory(Notification.CATEGORY_ALARM)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setOngoing(true)
                .setAutoCancel(false)
                .setContentIntent(fullScreen)
                .setFullScreenIntent(fullScreen, true);
        Notification n = b.build();
        // Swiping the notification away must not silence the alarm.
        n.flags |= Notification.FLAG_NO_CLEAR | Notification.FLAG_ONGOING_EVENT;
        return n;
    }

    /**
     * Android only shows the full-screen intent when the screen is off or locked; while the phone is
     * in use it shows a small heads-up instead. If our app is on screen, open the alarm screen directly.
     * When the app is in the background Android blocks this start, and the notification covers it.
     */
    private void bringAlarmScreenToFront() {
        try {
            startActivity(new Intent(this, MainActivity.class)
                    .putExtra(MainActivity.EXTRA_OPEN_ALARM, alarmId)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP));
        } catch (RuntimeException e) {
            Log.i(TAG, "alarm screen not opened directly: " + e.getMessage());
        }
    }

    private void startSpeaking() {
        readCount = 0;
        if (tts != null) {
            speak();
            return;
        }
        tts = new TextToSpeech(this, status -> {
            ttsReady = status == TextToSpeech.SUCCESS;
            if (!ttsReady) {
                Log.w(TAG, "TTS init failed: " + status);
                return;
            }
            int lang = tts.setLanguage(new Locale("vi", "VN"));
            vietnameseVoice = lang != TextToSpeech.LANG_MISSING_DATA && lang != TextToSpeech.LANG_NOT_SUPPORTED;
            Log.i(TAG, "TTS ready, vietnameseVoice=" + vietnameseVoice);
            tts.setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build());
            tts.setSpeechRate(0.9f);
            tts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                @Override
                public void onStart(String utteranceId) {
                }

                @Override
                public void onDone(String utteranceId) {
                    scheduleNextRead();
                }

                @Override
                public void onError(String utteranceId) {
                    scheduleNextRead();
                }
            });
            speak();
        });
    }

    private void speak() {
        if (!ttsReady || alarmId < 0) return;
        // Without a Vietnamese voice the text would be read as gibberish; keep ringing by vibration
        // and the on-screen alarm instead (plan §9), and retry later in case data gets installed.
        if (!vietnameseVoice) {
            Log.w(TAG, "no Vietnamese voice, skipping speech (read " + readCount + ")");
            scheduleNextRead();
            return;
        }
        readCount++;
        Bundle params = new Bundle();
        params.putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, android.media.AudioManager.STREAM_ALARM);
        tts.speak(speech, TextToSpeech.QUEUE_FLUSH, params, "alarm-" + alarmId + "-" + readCount);
        Log.i(TAG, "speaking read #" + readCount);
    }

    private void scheduleNextRead() {
        handler.removeCallbacks(speakAgain);
        if (alarmId >= 0) handler.postDelayed(speakAgain, PAUSE_BETWEEN_READS_MS);
    }

    private void startVibration() {
        Vibrator v = getSystemService(Vibrator.class);
        if (v == null || !v.hasVibrator()) return;
        long[] pattern = {0, 600, 400, 600, 400, 600, 2000};
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            v.vibrate(VibrationEffect.createWaveform(pattern, 0),
                    new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build());
        } else {
            v.vibrate(pattern, 0);
        }
    }

    private void acquireWakeLock() {
        if (wakeLock != null && wakeLock.isHeld()) return;
        PowerManager pm = getSystemService(PowerManager.class);
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "antam:alarm");
        wakeLock.acquire(); // Released when the alarm is confirmed or snoozed.
    }

    private void stopRinging() {
        Log.i(TAG, "stop alarm " + alarmId + " after " + readCount + " reads");
        alarmId = -1;
        running = false;
        handler.removeCallbacks(speakAgain);
        if (tts != null) tts.stop();
        Vibrator v = getSystemService(Vibrator.class);
        if (v != null) v.cancel();
        if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();
        AlarmStore.setRinging(this, -1);
        stopForeground(STOP_FOREGROUND_REMOVE);
        stopSelf();
    }

    @Override
    public void onDestroy() {
        running = false;
        handler.removeCallbacks(speakAgain);
        if (tts != null) tts.shutdown();
        if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
