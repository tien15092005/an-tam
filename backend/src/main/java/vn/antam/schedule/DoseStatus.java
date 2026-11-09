package vn.antam.schedule;

import java.time.Duration;
import java.time.LocalDateTime;

/** Status of one scheduled dose. Mirrored in the app (lib/domain/dose_status.dart); both pass shared/test-vectors. */
public enum DoseStatus {
    UPCOMING,
    DUE,
    MISSED,
    TAKEN,
    NOT_TAKEN,
    SKIPPED,
    /** The dose time had already passed when the medication was added, so it neither counts nor reminds. */
    NOT_APPLICABLE;

    public static final Duration GRACE = Duration.ofMinutes(60);

    /**
     * @param due       the scheduled local date-time
     * @param now       current local time in the elder's time zone
     * @param createdAt when the medication version was created, in the elder's local time
     * @param logStatus the recorded status (TAKEN, NOT_TAKEN, SKIPPED) or null if nothing was recorded
     */
    public static DoseStatus of(LocalDateTime due, LocalDateTime now, LocalDateTime createdAt, String logStatus) {
        if (logStatus != null) return DoseStatus.valueOf(logStatus);
        if (createdAt.withSecond(0).withNano(0).isAfter(due)) return NOT_APPLICABLE;
        if (now.isBefore(due)) return UPCOMING;
        return Duration.between(due, now).compareTo(GRACE) <= 0 ? DUE : MISSED;
    }
}
