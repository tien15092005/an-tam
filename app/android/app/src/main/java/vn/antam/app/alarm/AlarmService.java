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
 * through the ALARM audio stream until the user confirms or snoozes.
 * <p>
 * A ring lasts at most {@link #RING_LIMIT_MS}. Unanswered, the phone goes quiet and rings again
 * {@link #RETRY_AFTER_MS} after the ring started, up to {@link #MAX_ATTEMPTS} rings in all (snoozes count too).
 * Without a Vietnamese voice it plays the phone's alarm sound instead of reading aloud.
 * After the last one it stays quiet; caregivers are told by the server 30 minutes after the dose time
 * (SKILL_AN_TAM.md §9). A quiet notification tells the elder the dose still waits for an answer.
 */
public class AlarmService extends Service {

    static final String TAG = "AnTamAlarm";
    static final String CHANNEL_ID = "antam_alarm";
    static final int NOTIFICATION_ID = 4711;
    static final String ACTION_RING = "vn.antam.app.alarm.RING";
    static final String ACTION_STOP = "vn.antam.app.alarm.STOP";
    static final String ACTION_HOLD = "vn.antam.app.alarm.HOLD";
    static final long PAUSE_BETWEEN_READS_MS = 20_000;
    static final long RING_LIMIT_MS = AlarmPolicy.RING_LIMIT_MS;
    static final long RETRY_AFTER_MS = AlarmPolicy.RETRY_AFTER_MS;
    static final int MAX_ATTEMPTS = AlarmPolicy.MAX_ATTEMPTS;
    static final String MISSED_CHANNEL_ID = "antam_missed";
    static final int MISSED_NOTIFICATION_ID = 4712;

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
    private final Runnable giveUp = this::ringTimedOut;
    /** The phone's own alarm sound, used when there is no Vietnamese voice to read the reminder. */
    private android.media.MediaPlayer tone;
    private final Runnable resumeTone = this::resumeFallbackTone;
    private long ringStartedAt;
    /** The alarms of this ring (several when one joins another), to ring them again if unanswered. */
    private final java.util.Map<Integer, AlarmStore.Alarm> ringingNow = new java.util.LinkedHashMap<>();

    static void start(Context context, AlarmStore.Alarm alarm) {
        Intent intent = new Intent(context, AlarmService.class)
                .setAction(ACTION_RING)
                .putExtra(AlarmScheduler.EXTRA_ALARM_ID, alarm.id)
                .putExtra("title", alarm.title)
                .putExtra("speech", alarm.speech)
                .putExtra("attempt", alarm.attempt);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent);
        } else {
            context.startService(intent);
        }
    }

    /**
     * Pauses the spoken reminder for [ms] while the elder answers by voice, so the microphone does not
     * hear the phone itself. Vibration and the on-screen alarm continue; reading resumes afterwards.
     */
    public static void hold(Context context, long ms) {
        if (!running) return;
        context.startService(new Intent(context, AlarmService.class).setAction(ACTION_HOLD).putExtra("ms", ms));
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
        if (ACTION_HOLD.equals(intent.getAction())) {
            long ms = Math.min(intent.getLongExtra("ms", 8000), 30_000);
            handler.removeCallbacks(speakAgain);
            handler.removeCallbacks(resumeTone);
            if (tts != null) tts.stop();
            if (tone != null && tone.isPlaying()) {
                tone.pause();
                handler.postDelayed(resumeTone, ms);
            }
            if (alarmId >= 0) handler.postDelayed(speakAgain, ms);
            return START_NOT_STICKY;
        }
        alarmId = intent.getIntExtra(AlarmScheduler.EXTRA_ALARM_ID, -1);
        String title = intent.getStringExtra("title");
        speech = intent.getStringExtra("speech");
        int attempt = Math.max(1, intent.getIntExtra("attempt", 1));
        if (title == null) title = "Đến giờ uống thuốc";
        getSystemService(NotificationManager.class).cancel(MISSED_NOTIFICATION_ID);
        startInForeground(buildNotification(title));
        running = true;
        // A new alarm while one is still unanswered joins it: one screen, one voice, never two at once.
        AlarmStore.addRinging(this, alarmId, attempt);
        ringingNow.put(alarmId, new AlarmStore.Alarm(alarmId, 0, title, speech == null ? "" : speech, attempt));
        ringStartedAt = System.currentTimeMillis();
        handler.removeCallbacks(giveUp);
        handler.postDelayed(giveUp, RING_LIMIT_MS);
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
                startFallbackTone();
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
            // Reading Vietnamese with another language's voice is gibberish: ring the phone's alarm sound instead,
            // so an elder who does not see the screen still hears something.
            Log.w(TAG, "no Vietnamese voice, ringing the alarm sound instead");
            startFallbackTone();
            return;
        }
        readCount++;
        Bundle params = new Bundle();
        params.putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, android.media.AudioManager.STREAM_ALARM);
        tts.speak(speech, TextToSpeech.QUEUE_FLUSH, params, "alarm-" + alarmId + "-" + readCount);
        Log.i(TAG, "speaking read #" + readCount);
    }

    private void startFallbackTone() {
        if (alarmId < 0 || (tone != null && tone.isPlaying())) return;
        android.net.Uri uri = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_ALARM);
        if (uri == null) uri = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_RINGTONE);
        if (uri == null) uri = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION);
        if (uri == null) return;
        try {
            releaseTone();
            tone = new android.media.MediaPlayer();
            tone.setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build());
            tone.setDataSource(this, uri);
            tone.setLooping(true);
            tone.prepare();
            tone.start();
        } catch (Exception e) {
            Log.w(TAG, "fallback alarm sound failed: " + e.getMessage());
            releaseTone();
        }
    }

    private void resumeFallbackTone() {
        if (alarmId >= 0 && tone != null && !tone.isPlaying()) tone.start();
    }

    private void releaseTone() {
        handler.removeCallbacks(resumeTone);
        if (tone == null) return;
        try {
            tone.stop();
        } catch (IllegalStateException ignored) {
            // Not started yet.
        }
        tone.release();
        tone = null;
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

    /** Nobody answered within the ring limit: go quiet, ring again later unless this was the last attempt. */
    private void ringTimedOut() {
        if (!running) return;
        int lastAttempt = 0;
        long retryAt = AlarmPolicy.retryAt(ringStartedAt, System.currentTimeMillis());
        String title = null;
        for (AlarmStore.Alarm a : ringingNow.values()) {
            lastAttempt = Math.max(lastAttempt, a.attempt);
            title = a.title.startsWith("Nhắc lại: ") ? a.title.substring("Nhắc lại: ".length()) : a.title;
            if (AlarmPolicy.mayRingAgain(a.attempt)) {
                AlarmScheduler.schedule(this, AlarmScheduler.followUpId(a.id), retryAt, "Nhắc lại: " + title, a.speech,
                        a.attempt + 1);
            }
        }
        Log.i(TAG, "alarm " + alarmId + " unanswered after attempt " + lastAttempt);
        showMissedNotification(title == null ? "uống thuốc" : title, AlarmPolicy.mayRingAgain(lastAttempt) ? retryAt : -1);
        stopRinging();
    }

    private void showMissedNotification(String title, long retryAt) {
        NotificationManager nm = getSystemService(NotificationManager.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && nm.getNotificationChannel(MISSED_CHANNEL_ID) == null) {
            nm.createNotificationChannel(new NotificationChannel(MISSED_CHANNEL_ID, "Thuốc chưa xác nhận",
                    NotificationManager.IMPORTANCE_DEFAULT));
        }
        PendingIntent open = PendingIntent.getActivity(this, MISSED_NOTIFICATION_ID,
                new Intent(this, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        String text = retryAt > 0
                ? "Máy sẽ nhắc lại lúc " + new java.text.SimpleDateFormat("HH:mm", Locale.getDefault()).format(new java.util.Date(retryAt))
                + ". Uống rồi thì mở app bấm Đã uống."
                : "Mở app để trả lời. Các con sẽ được báo nếu chưa có trả lời.";
        Notification.Builder b = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? new Notification.Builder(this, MISSED_CHANNEL_ID)
                : new Notification.Builder(this);
        b.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("Chưa xác nhận: " + title)
                .setContentText(text)
                .setStyle(new Notification.BigTextStyle().bigText(text))
                .setCategory(Notification.CATEGORY_REMINDER)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .setContentIntent(open);
        nm.notify(MISSED_NOTIFICATION_ID, b.build());
    }

    /** Cancels the automatic re-rings of the given alarm (the dose was answered elsewhere). */
    static void cancelFollowUp(Context context, int id) {
        AlarmScheduler.cancel(context, AlarmScheduler.followUpId(id));
        context.getSystemService(NotificationManager.class).cancel(MISSED_NOTIFICATION_ID);
    }

    private void stopRinging() {
        Log.i(TAG, "stop alarm " + alarmId + " after " + readCount + " reads");
        alarmId = -1;
        running = false;
        ringingNow.clear();
        handler.removeCallbacks(giveUp);
        handler.removeCallbacks(speakAgain);
        releaseTone();
        if (tts != null) tts.stop();
        Vibrator v = getSystemService(Vibrator.class);
        if (v != null) v.cancel();
        if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();
        AlarmStore.clearRinging(this);
        stopForeground(STOP_FOREGROUND_REMOVE);
        stopSelf();
    }

    @Override
    public void onDestroy() {
        running = false;
        handler.removeCallbacks(giveUp);
        handler.removeCallbacks(speakAgain);
        releaseTone();
        if (tts != null) tts.shutdown();
        if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
