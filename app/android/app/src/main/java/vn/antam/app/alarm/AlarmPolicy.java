package vn.antam.app.alarm;

/**
 * The alarm rules as plain functions, with no Android types, so they run in ordinary unit tests
 * ({@code ./gradlew :app:testDebugUnitTest}).
 */
public final class AlarmPolicy {

    /** One ring lasts at most this long before the phone goes quiet. */
    public static final long RING_LIMIT_MS = 2 * 60_000;
    /** An unanswered ring comes back this long after it started. */
    public static final long RETRY_AFTER_MS = 10 * 60_000;
    /** Rings per dose, snoozes included: at the dose time, +10 and +20 minutes. */
    public static final int MAX_ATTEMPTS = 3;
    /** After a reboot, an alarm missed by less than this still rings at once; older ones are dropped. */
    public static final long CATCH_UP_MS = 30 * 60_000;
    /** Below this share of the maximum, the alarm volume counts as too low on the readiness screen. */
    public static final double MIN_ALARM_VOLUME = 0.5;
    /** "Tăng âm lượng" sets the alarm stream to this share of the maximum. */
    public static final double RAISED_ALARM_VOLUME = 0.8;

    private AlarmPolicy() {
    }

    /** Repeats of a schedule alarm live below the schedule range; a repeat of a repeat keeps its id. */
    public static int followUpId(int id) {
        return id >= AlarmScheduler.SCHEDULE_ID_BASE ? id - AlarmScheduler.FOLLOW_UP_OFFSET : id;
    }

    /** True while another automatic ring is still allowed after this one. */
    public static boolean mayRingAgain(int attempt) {
        return attempt < MAX_ATTEMPTS;
    }

    /** When to ring again: 10 minutes after the ring started, but never sooner than a minute from now. */
    public static long retryAt(long ringStartedAt, long now) {
        return Math.max(ringStartedAt + RETRY_AFTER_MS, now + 60_000);
    }

    /** What to do with a stored alarm when the phone starts again. */
    public enum Rearm { ARM, RING_NOW, DROP }

    public static Rearm onRestart(long triggerAtMillis, long now) {
        if (triggerAtMillis > now) return Rearm.ARM;
        return now - triggerAtMillis < CATCH_UP_MS ? Rearm.RING_NOW : Rearm.DROP;
    }

    public static boolean volumeTooLow(int volume, int max) {
        return max <= 0 || volume < Math.ceil(max * MIN_ALARM_VOLUME);
    }

    public static int raisedVolume(int max) {
        return (int) Math.ceil(max * RAISED_ALARM_VOLUME);
    }
}
