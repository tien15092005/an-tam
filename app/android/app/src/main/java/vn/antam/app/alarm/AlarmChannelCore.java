package vn.antam.app.alarm;

import android.content.Context;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import vn.antam.app.sync.BackgroundSync;

/**
 * The parts of the "vn.antam/alarm" channel that need no Activity: scheduling and background sync.
 * Used by MainActivity and by the headless engine of {@link BackgroundSync}, so a sync in the background
 * re-arms alarms exactly like the app does.
 */
public final class AlarmChannelCore {

    public static final String CHANNEL = "vn.antam/alarm";

    private AlarmChannelCore() {
    }

    /** For a headless engine: the core methods, nothing that needs a screen. */
    public static void attach(Context context, BinaryMessenger messenger) {
        new MethodChannel(messenger, CHANNEL).setMethodCallHandler((call, result) -> {
            if (!handle(context, call, result)) result.notImplemented();
        });
    }

    /** @return false when the method is not one of the core ones (the caller handles it). */
    public static boolean handle(Context context, MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "schedule": {
                Integer id = call.argument("id");
                Number at = call.argument("triggerAtMillis");
                String title = call.argument("title");
                String speech = call.argument("speech");
                Integer attempt = call.argument("attempt");
                if (id == null || at == null || title == null || speech == null) {
                    result.error("bad_args", "id, triggerAtMillis, title, speech are required", null);
                } else {
                    AlarmScheduler.schedule(context, id, at.longValue(), title, speech, attempt == null ? 1 : attempt);
                    result.success(null);
                }
                return true;
            }
            case "replaceSchedule": {
                List<Map<String, Object>> raw = call.argument("alarms");
                List<AlarmStore.Alarm> alarms = new ArrayList<>();
                if (raw != null) {
                    for (Map<String, Object> a : raw) {
                        alarms.add(new AlarmStore.Alarm(((Number) a.get("id")).intValue(),
                                ((Number) a.get("triggerAtMillis")).longValue(), (String) a.get("title"), (String) a.get("speech")));
                    }
                }
                AlarmScheduler.replaceSchedule(context, alarms);
                result.success(alarms.size());
                return true;
            }
            case "scheduled": {
                List<Map<String, Object>> out = new ArrayList<>();
                for (AlarmStore.Alarm a : AlarmScheduler.all(context)) {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", a.id);
                    m.put("triggerAtMillis", a.triggerAtMillis);
                    m.put("title", a.title);
                    out.add(m);
                }
                result.success(out);
                return true;
            }
            case "cancel": {
                Integer id = call.argument("id");
                if (id != null) AlarmScheduler.cancel(context, id);
                result.success(null);
                return true;
            }
            case "ringingIds":
                result.success(AlarmScheduler.ringingIds(context));
                return true;
            case "answered": {
                // Doses answered (by the elder, or marked by a caregiver): no automatic re-ring for them.
                List<Integer> ids = call.argument("ids");
                if (ids != null) for (Integer id : ids) AlarmService.cancelFollowUp(context, id);
                result.success(null);
                return true;
            }
            case "ringingAttempt":
                result.success(AlarmScheduler.ringingAttempt(context));
                return true;
            case "backgroundSync": {
                Boolean enabled = call.argument("enabled");
                BackgroundSync.setEnabled(context, Boolean.TRUE.equals(enabled));
                result.success(null);
                return true;
            }
            default:
                return false;
        }
    }
}
