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
        /** 1 for the alarm at the dose time, 2 and 3 for the reminders after it (see AlarmService). */
        public final int attempt;

        public Alarm(int id, long triggerAtMillis, String title, String speech) {
            this(id, triggerAtMillis, title, speech, 1);
        }

        public Alarm(int id, long triggerAtMillis, String title, String speech, int attempt) {
            this.id = id;
            this.triggerAtMillis = triggerAtMillis;
            this.title = title;
            this.speech = speech;
            this.attempt = Math.max(1, attempt);
        }

        JSONObject toJson() throws JSONException {
            return new JSONObject()
                    .put("id", id)
                    .put("triggerAtMillis", triggerAtMillis)
                    .put("title", title)
                    .put("speech", speech)
                    .put("attempt", attempt);
        }

        static Alarm fromJson(JSONObject o) throws JSONException {
            return new Alarm(o.getInt("id"), o.getLong("triggerAtMillis"), o.getString("title"), o.getString("speech"),
                    o.optInt("attempt", 1));
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
        for (int[] r : ringing(context)) ids.add(r[0]);
        return ids;
    }

    /** The highest attempt among the alarms ringing now (1 = at the dose time), or 0 when nothing rings. */
    static synchronized int ringingAttempt(Context context) {
        int max = 0;
        for (int[] r : ringing(context)) max = Math.max(max, r[1]);
        return max;
    }

    /** Pairs of {id, attempt}, stored as "id:attempt,id:attempt". */
    private static List<int[]> ringing(Context context) {
        List<int[]> out = new ArrayList<>();
        for (String part : prefs(context).getString(KEY_RINGING, "").split(",")) {
            if (part.isEmpty()) continue;
            String[] p = part.split(":");
            out.add(new int[]{Integer.parseInt(p[0]), p.length > 1 ? Integer.parseInt(p[1]) : 1});
        }
        return out;
    }

    static synchronized void addRinging(Context context, int id, int attempt) {
        List<int[]> all = ringing(context);
        all.removeIf(r -> r[0] == id);
        all.add(new int[]{id, attempt});
        StringBuilder sb = new StringBuilder();
        for (int[] r : all) sb.append(sb.length() == 0 ? "" : ",").append(r[0]).append(':').append(r[1]);
        prefs(context).edit().putString(KEY_RINGING, sb.toString()).apply();
    }

    static synchronized void clearRinging(Context context) {
        prefs(context).edit().remove(KEY_RINGING).apply();
    }
}
