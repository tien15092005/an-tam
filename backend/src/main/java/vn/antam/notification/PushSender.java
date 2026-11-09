package vn.antam.notification;

import java.util.Map;

/** Delivers one push to one app install. FCM in production; a recording fake in tests. */
public interface PushSender {

    enum Result {
        SENT,
        /** The install is gone (app removed, token rotated): forget this token. */
        INVALID_TOKEN,
        /** Network or server trouble: try again later. */
        RETRY
    }

    /** False when pushes are not configured (no Firebase credentials): entries are closed as DISABLED. */
    boolean enabled();

    /**
     * @param title  shown by the phone when non-null; data-only otherwise (e.g. "stop ringing")
     * @param urgent high priority, so the phone wakes from Doze
     */
    Result send(String token, String title, String body, Map<String, String> data, boolean urgent);
}
