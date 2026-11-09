package vn.antam.app.alarm;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/**
 * Persists scheduled alarms on the device so they can be re-armed after a reboot,
 * an app update or a time/time-zone change, without needing the backend.
 */
public final class AlarmStore {

    private static final String PREFS = "antam_alarms";
    private static final String KEY_ALARMS = "alarms";
    private static final String KEY_RINGING = "ringing_ids";

    public static final class Alarm {
        public final int id;
        public final long triggerAtMillis;
        public final String title;
        public final String speech;

        public Alarm(int id, long triggerAtMillis, String title, String speech) {
            this.id = id;
            this.triggerAtMillis = triggerAtMillis;
            this.title = title;
            this.speech = speech;
        }

        JSONObject toJson() throws JSONException {
            return new JSONObject()
                    .put("id", id)
                    .put("triggerAtMillis", triggerAtMillis)
                    .put("title", title)
                    .put("speech", speech);
        }

        static Alarm fromJson(JSONObject o) throws JSONException {
            return new Alarm(o.getInt("id"), o.getLong("triggerAtMillis"), o.getString("title"), o.getString("speech"));
        }
    }

    private AlarmStore() {
    }

    private static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    static synchronized List<Alarm> all(Context context) {
        List<Alarm> result = new ArrayList<>();
        try {
            JSONArray array = new JSONArray(prefs(context).getString(KEY_ALARMS, "[]"));
            for (int i = 0; i < array.length(); i++) {
                result.add(Alarm.fromJson(array.getJSONObject(i)));
            }
        } catch (JSONException ignored) {
            // Corrupt data: treat as no alarms rather than crash the alarm path.
        }
        return result;
    }

    static synchronized Alarm find(Context context, int id) {
        for (Alarm a : all(context)) {
            if (a.id == id) return a;
        }
        return null;
    }

    static synchronized void put(Context context, Alarm alarm) {
        List<Alarm> alarms = all(context);
        alarms.removeIf(a -> a.id == alarm.id);
        alarms.add(alarm);
        save(context, alarms);
    }

    static synchronized void remove(Context context, int id) {
        List<Alarm> alarms = all(context);
        alarms.removeIf(a -> a.id == id);
        save(context, alarms);
    }

    private static void save(Context context, List<Alarm> alarms) {
        JSONArray array = new JSONArray();
        try {
            for (Alarm a : alarms) array.put(a.toJson());
        } catch (JSONException ignored) {
            return;
        }
        prefs(context).edit().putString(KEY_ALARMS, array.toString()).apply();
    }

    /** Alarms ringing now (several when a new one fires before the last was answered), oldest first. */
    static synchronized List<Integer> ringingIds(Context context) {
        List<Integer> ids = new ArrayList<>();
        for (String part : prefs(context).getString(KEY_RINGING, "").split(",")) {
            if (!part.isEmpty()) ids.add(Integer.parseInt(part));
        }
        return ids;
    }

    static synchronized void addRinging(Context context, int id) {
        List<Integer> ids = ringingIds(context);
        if (!ids.contains(id)) ids.add(id);
        StringBuilder sb = new StringBuilder();
        for (int i : ids) sb.append(sb.length() == 0 ? "" : ",").append(i);
        prefs(context).edit().putString(KEY_RINGING, sb.toString()).apply();
    }

    static synchronized void clearRinging(Context context) {
        prefs(context).edit().remove(KEY_RINGING).apply();
    }
}
