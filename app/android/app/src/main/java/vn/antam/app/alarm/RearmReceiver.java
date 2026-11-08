package vn.antam.app.alarm;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * AlarmManager forgets alarms on reboot and may drift after clock changes,
 * so stored alarms are re-armed on boot, app update, and time / time-zone changes.
 */
public class RearmReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        AlarmScheduler.rearmAll(context);
    }
}
