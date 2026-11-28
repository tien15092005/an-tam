package vn.antam.notification;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import java.time.Instant;

import org.junit.jupiter.api.Test;

class OutboxEntryTest {

    private final Instant t0 = Instant.parse("2026-11-28T01:00:00Z");

    @Test
    void retriesWaitLongerEachTimeUpToTenMinutes() {
        OutboxEntry e = new OutboxEntry("k", 1L, "ALERT", 1L, 1L, "Bà Lan báo không khỏe", "", true, t0);
        Instant now = t0;
        long[] expectedSeconds = {10, 20, 40, 80, 160, 320, 600, 600};
        for (long s : expectedSeconds) {
            e.failed("push service unavailable", now);
            assertThat(e.getStatus()).isEqualTo(OutboxEntry.Status.PENDING);
            assertThat(Duration.between(now, e.getNextAttemptAt()).toSeconds()).isEqualTo(s);
            now = e.getNextAttemptAt();
        }
    }

    @Test
    void anUrgentAlertIsStillRetriedAfterAnHourButAReportIsNot() {
        OutboxEntry alert = new OutboxEntry("a", 1L, "ALERT", 1L, 1L, "t", "b", true, t0);
        OutboxEntry report = new OutboxEntry("r", 1L, "DOSE_REPORT", 1L, 1L, "t", "b", false, t0);
        Instant later = t0.plus(Duration.ofMinutes(61));
        alert.failed("down", later);
        report.failed("down", later);
        assertThat(alert.getStatus()).isEqualTo(OutboxEntry.Status.PENDING);
        assertThat(report.getStatus()).isEqualTo(OutboxEntry.Status.FAILED);
        alert.failed("down", t0.plus(Duration.ofHours(6)));
        assertThat(alert.getStatus()).isEqualTo(OutboxEntry.Status.FAILED);
    }
}
