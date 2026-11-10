package vn.antam.app.sync;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;

import java.util.concurrent.atomic.AtomicBoolean;

import io.flutter.FlutterInjector;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.embedding.engine.loader.FlutterLoader;
import io.flutter.plugin.common.MethodChannel;
import vn.antam.app.alarm.AlarmChannelCore;

/**
 * The fallback of plan §9 ("worker định kỳ"): every few hours, even when the app is never opened and no
 * push arrives, the elder's phone downloads its schedule and re-arms the next 7 days of alarms. A headless
 * Flutter engine runs the Dart entry point {@code backgroundSync} (lib/main.dart), which reuses the app's
 * own sync code. Enabled on elder phones only; survives reboots through RearmReceiver.
 */
public final class BackgroundSync {

    private static final String TAG = "AnTamSync";
    private static final String PREFS = "antam_background_sync";
    private static final String KEY_ENABLED = "enabled";
    private static final String KEY_INTERVAL = "interval_ms";
    static final long INTERVAL_MS = 3 * AlarmManager.INTERVAL_HOUR;
    private static final long TIMEOUT_MS = 50_000;

    private BackgroundSync() {
    }

    public static boolean isEnabled(Context context) {
        return prefs(context).getBoolean(KEY_ENABLED, false);
    }

    public static void setEnabled(Context context, boolean enabled) {
        prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply();
        if (enabled) schedule(context);
        else alarmManager(context).cancel(pendingIntent(context));
    }

    /** Inexact on purpose: the system batches it with other work, so it costs little battery. */
    public static void schedule(Context context) {
        if (!isEnabled(context)) return;
        long interval = prefs(context).getLong(KEY_INTERVAL, INTERVAL_MS);
        alarmManager(context).setInexactRepeating(AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime() + interval, interval, pendingIntent(context));
    }

    /** Debug builds only (see MainActivity): a short interval to test the receiver without waiting hours. */
    public static void setIntervalForDebug(Context context, long ms) {
        prefs(context).edit().putLong(KEY_INTERVAL, Math.max(60_000L, ms)).apply();
        schedule(context);
    }

    /** From SyncReceiver: the open app refreshes itself; otherwise a headless engine does it. */
    static void runFromAlarm(Context app, Runnable onFinished) {
        if (vn.antam.app.MainActivity.requestSyncInOpenApp()) {
            Log.i(TAG, "background sync handed to the open app");
            onFinished.run();
            return;
        }
        Log.i(TAG, "background sync started (headless)");
        runOnce(app, onFinished);
    }

    public static void runNowForDebug(Context app) {
        Log.i(TAG, "background sync started (debug)");
        runOnce(app, () -> Log.i(TAG, "background sync finished"));
    }

    /** Runs the Dart sync once on the main thread, then calls {@code onFinished} (also after a timeout). */
    static void runOnce(Context app, Runnable onFinished) {
        Handler main = new Handler(Looper.getMainLooper());
        main.post(() -> {
            try {
                FlutterLoader loader = FlutterInjector.instance().flutterLoader();
                loader.startInitialization(app);
                loader.ensureInitializationCompleteAsync(app, null, main, () -> start(app, loader, main, onFinished));
            } catch (RuntimeException e) {
                Log.w(TAG, "background sync could not start", e);
                onFinished.run();
            }
        });
    }

    private static void start(Context app, FlutterLoader loader, Handler main, Runnable onFinished) {
        FlutterEngine engine = new FlutterEngine(app);
        AtomicBoolean finished = new AtomicBoolean(false);
        Runnable finish = () -> {
            if (!finished.compareAndSet(false, true)) return;
            engine.destroy();
            onFinished.run();
        };
        AlarmChannelCore.attach(app, engine.getDartExecutor().getBinaryMessenger());
        new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "vn.antam/background")
                .setMethodCallHandler((call, result) -> {
                    result.success(null);
                    Log.i(TAG, "background sync " + call.method);
                    main.post(finish);
                });
        main.postDelayed(finish, TIMEOUT_MS);
        engine.getDartExecutor().executeDartEntrypoint(
                new DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "backgroundSync"));
    }

    private static PendingIntent pendingIntent(Context context) {
        Intent i = new Intent(context, SyncReceiver.class);
        return PendingIntent.getBroadcast(context, 7, i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private static AlarmManager alarmManager(Context context) {
        return (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
    }

    private static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }
}
