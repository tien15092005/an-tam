package vn.antam.app.alarm;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Fired by AlarmManager at the alarm time; hands over to the foreground service that rings and speaks. */
public class AlarmReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        int id = intent.getIntExtra(AlarmScheduler.EXTRA_ALARM_ID, -1);
        AlarmStore.Alarm alarm = AlarmStore.find(context, id);
        if (alarm == null) return;
        AlarmStore.remove(context, id);
        AlarmService.start(context, alarm);
    }
}
