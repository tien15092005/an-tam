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
        AlarmStore.put(context, new AlarmStore.Alarm(id, triggerAtMillis, title, speech));
        arm(context, id, triggerAtMillis);
    }

    /** The alarm currently ringing, or -1. */
    public static int ringingId(Context context) {
        int id = AlarmStore.ringingId(context);
        if (id >= 0 && !AlarmService.running) {
            // The process died while ringing (e.g. app update); the flag is left over, not a live alarm.
            AlarmStore.setRinging(context, -1);
            return -1;
        }
        return id;
    }

    public static void cancel(Context context, int id) {
        AlarmManager am = context.getSystemService(AlarmManager.class);
        if (am != null) am.cancel(firePendingIntent(context, id));
        AlarmStore.remove(context, id);
    }

    /** Re-arms every stored alarm that is still in the future; drops the ones already past. */
    static void rearmAll(Context context) {
        long now = System.currentTimeMillis();
        for (AlarmStore.Alarm a : AlarmStore.all(context)) {
            if (a.triggerAtMillis > now) {
                arm(context, a.id, a.triggerAtMillis);
            } else {
                AlarmStore.remove(context, a.id);
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
