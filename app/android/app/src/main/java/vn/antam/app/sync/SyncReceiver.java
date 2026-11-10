package vn.antam.app.sync;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Fired every few hours by {@link BackgroundSync}; keeps the process alive until the Dart sync is done. */
public class SyncReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (!BackgroundSync.isEnabled(context)) return;
        PendingResult pending = goAsync();
        BackgroundSync.runFromAlarm(context.getApplicationContext(), pending::finish);
    }
}
