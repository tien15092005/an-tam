package vn.antam.common;

import java.time.Clock;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;

import vn.antam.care.DoseSweeper;
import vn.antam.notification.OutboxDispatcher;

/**
 * Background work. Both jobs run soon after start-up, so whatever happened while the laptop was off
 * (unconfirmed doses, queued notifications) is caught up. Tests switch this off and call the jobs directly.
 */
@Configuration
@EnableScheduling
@ConditionalOnProperty(name = "antam.jobs.enabled", havingValue = "true", matchIfMissing = true)
public class Jobs {

    private final DoseSweeper sweeper;
    private final OutboxDispatcher dispatcher;
    private final Clock clock;
    private final org.springframework.jdbc.core.JdbcTemplate jdbc;
    private final vn.antam.medication.ImageStore images;
    private final vn.antam.auth.AttemptLimiter limiter;

    public Jobs(DoseSweeper sweeper, OutboxDispatcher dispatcher, Clock clock, org.springframework.jdbc.core.JdbcTemplate jdbc,
                vn.antam.medication.ImageStore images, vn.antam.auth.AttemptLimiter limiter) {
        this.sweeper = sweeper;
        this.dispatcher = dispatcher;
        this.clock = clock;
        this.jdbc = jdbc;
        this.images = images;
        this.limiter = limiter;
    }

    /** Photo files deleted more than 30 days ago are removed from disk (plan §6); history keeps name snapshots. */
    @Scheduled(initialDelayString = "PT2M", fixedDelayString = "PT12H")
    void purgeDeletedPhotos() {
        java.sql.Timestamp cutoff = java.sql.Timestamp.from(clock.instant().minus(java.time.Duration.ofDays(30)));
        for (var row : jdbc.queryForList(
                "SELECT id, storage_key FROM medication_images WHERE deleted_at < ? AND file_purged_at IS NULL", cutoff)) {
            images.delete((String) row.get("storage_key"));
            jdbc.update("UPDATE medication_images SET file_purged_at = ? WHERE id = ?",
                    java.sql.Timestamp.from(clock.instant()), row.get("id"));
        }
    }

    /**
     * How long history is kept: resolved alerts 1 year, the change log 2 years, used or expired codes 30 days.
     * Dose logs stay (they are the medicine history families look back on) until the family or parent is deleted.
     */
    @Scheduled(initialDelayString = "PT4M", fixedDelayString = "PT24H")
    void applyRetention() {
        java.time.Instant now = clock.instant();
        jdbc.update("DELETE FROM alerts WHERE resolved_at < ?", java.sql.Timestamp.from(now.minus(java.time.Duration.ofDays(365))));
        jdbc.update("DELETE FROM audit_logs WHERE created_at < ?", java.sql.Timestamp.from(now.minus(java.time.Duration.ofDays(730))));
        java.sql.Timestamp month = java.sql.Timestamp.from(now.minus(java.time.Duration.ofDays(30)));
        jdbc.update("DELETE FROM invites WHERE expires_at < ?", month);
        jdbc.update("DELETE FROM password_resets WHERE expires_at < ?", month);
        jdbc.update("DELETE FROM refresh_tokens WHERE expires_at < ? OR revoked_at < ?", month, month);
    }

    /** Attempt counters with nothing in the last hour are forgotten, so the map cannot grow without bound. */
    @Scheduled(initialDelayString = "PT10M", fixedDelayString = "PT10M")
    void forgetIdleAttemptCounters() {
        limiter.evictIdle(java.time.Duration.ofHours(1));
    }

    /** Delivered push texts repeat names and medicines; keep them a week for troubleshooting, then drop them. */
    @Scheduled(initialDelayString = "PT3M", fixedDelayString = "PT6H")
    void purgeOldNotifications() {
        jdbc.update("DELETE FROM notification_outbox WHERE status <> 'PENDING' AND created_at < ?",
                java.sql.Timestamp.from(clock.instant().minus(java.time.Duration.ofDays(7))));
    }

    @Scheduled(initialDelayString = "PT10S", fixedDelayString = "PT1M")
    void sweepUnconfirmedDoses() {
        sweeper.sweep(clock.instant());
    }

    @Scheduled(initialDelayString = "PT5S", fixedDelayString = "PT3S")
    void sendNotifications() {
        // A full batch means more may be waiting; at most a few rounds so retries wait for the next tick.
        for (int round = 0; round < 10 && dispatcher.dispatch() >= 50; round++) {
            // keep going
        }
    }
}
