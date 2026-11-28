package vn.antam.app.alarm;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import vn.antam.app.MainActivity;

/** Arms alarms with AlarmManager.setAlarmClock, the most reliable exact alarm Android offers. */
public final class AlarmScheduler {

    static final String EXTRA_ALARM_ID = "alarm_id";

    private AlarmScheduler() {
    }

    public static boolean canScheduleExact(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true;
        AlarmManager am = context.getSystemService(AlarmManager.class);
        return am != null && am.canScheduleExactAlarms();
    }

    public static void schedule(Context context, int id, long triggerAtMillis, String title, String speech) {
        schedule(context, id, triggerAtMillis, title, speech, 1);
    }

    public static void schedule(Context context, int id, long triggerAtMillis, String title, String speech, int attempt) {
        AlarmStore.put(context, new AlarmStore.Alarm(id, triggerAtMillis, title, speech, attempt));
        arm(context, id, triggerAtMillis);
    }

    /**
     * Reminders after a schedule alarm (snoozes and automatic repeats) use this offset below the schedule
     * range, so a re-sync never cancels them and the id still decodes to the dose minute.
     * Must match _snoozeOffset in alarm_screen.dart.
     */
    public static final int FOLLOW_UP_OFFSET = 50_000_000;

    static int followUpId(int id) {
        return AlarmPolicy.followUpId(id);
    }

    /** Highest attempt among the alarms ringing now; 0 when nothing rings. */
    public static int ringingAttempt(Context context) {
        return ringingIds(context).isEmpty() ? 0 : AlarmStore.ringingAttempt(context);
    }

    /** Ids from here up belong to the medication schedule; lower ids are one-off alarms such as snoozes. */
    public static final int SCHEDULE_ID_BASE = 100_000_000;

    /**
     * Makes the schedule's alarms exactly {@code alarms}: arms new or changed ones and cancels the
     * schedule alarms no longer listed (a deleted medication stops ringing). Snoozes are left alone.
     */
    public static void replaceSchedule(Context context, java.util.List<AlarmStore.Alarm> alarms) {
        java.util.Set<Integer> keep = new java.util.HashSet<>();
        for (AlarmStore.Alarm a : alarms) keep.add(a.id);
        for (AlarmStore.Alarm old : AlarmStore.all(context)) {
            if (old.id >= SCHEDULE_ID_BASE && !keep.contains(old.id)) cancel(context, old.id);
        }
        long now = System.currentTimeMillis();
        for (AlarmStore.Alarm a : alarms) {
            if (a.triggerAtMillis > now) schedule(context, a.id, a.triggerAtMillis, a.title, a.speech);
        }
    }

    public static java.util.List<AlarmStore.Alarm> all(Context context) {
        return AlarmStore.all(context);
    }

    /** The alarms ringing now, oldest first; empty when nothing rings. */
    public static java.util.List<Integer> ringingIds(Context context) {
        java.util.List<Integer> ids = AlarmStore.ringingIds(context);
        if (!ids.isEmpty() && !AlarmService.running) {
            // The process died while ringing (e.g. app update); the list is left over, not a live alarm.
            AlarmStore.clearRinging(context);
            return new java.util.ArrayList<>();
        }
        return ids;
    }

    /** Forgets the ringing list at once (the service stops a moment later), so the UI never bounces back. */
    public static void clearRinging(Context context) {
        AlarmStore.clearRinging(context);
    }

    /** The first alarm ringing now, or -1. */
    public static int ringingId(Context context) {
        java.util.List<Integer> ids = ringingIds(context);
        return ids.isEmpty() ? -1 : ids.get(0);
    }

    public static void cancel(Context context, int id) {
        AlarmManager am = context.getSystemService(AlarmManager.class);
        if (am != null) am.cancel(firePendingIntent(context, id));
        AlarmStore.remove(context, id);
    }

    /**
     * Re-arms every stored alarm still in the future. One the phone missed while it was off or restarting
     * (less than 30 minutes ago) rings at once, so a dose is not silently skipped; older ones are dropped.
     */
    static void rearmAll(Context context) {
        long now = System.currentTimeMillis();
        for (AlarmStore.Alarm a : AlarmStore.all(context)) {
            switch (AlarmPolicy.onRestart(a.triggerAtMillis, now)) {
                case ARM -> arm(context, a.id, a.triggerAtMillis);
                case RING_NOW -> {
                    AlarmStore.remove(context, a.id);
                    AlarmService.start(context, a);
                }
                case DROP -> AlarmStore.remove(context, a.id);
            }
        }
    }

    private static void arm(Context context, int id, long triggerAtMillis) {
        AlarmManager am = context.getSystemService(AlarmManager.class);
        if (am == null || !canScheduleExact(context)) return;
        // The "show" intent opens the app when the user taps the alarm icon in the status bar.
        PendingIntent show = PendingIntent.getActivity(context, id,
                new Intent(context, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        am.setAlarmClock(new AlarmManager.AlarmClockInfo(triggerAtMillis, show), firePendingIntent(context, id));
    }

    private static PendingIntent firePendingIntent(Context context, int id) {
        Intent intent = new Intent(context, AlarmReceiver.class).putExtra(EXTRA_ALARM_ID, id);
        return PendingIntent.getBroadcast(context, id, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }
}
