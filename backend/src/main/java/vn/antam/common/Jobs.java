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

    public Jobs(DoseSweeper sweeper, OutboxDispatcher dispatcher, Clock clock, org.springframework.jdbc.core.JdbcTemplate jdbc,
                vn.antam.medication.ImageStore images) {
        this.sweeper = sweeper;
        this.dispatcher = dispatcher;
        this.clock = clock;
        this.jdbc = jdbc;
        this.images = images;
    }

    /** Photo files deleted more than 30 days ago are removed from disk (plan §6); history keeps name snapshots. */
    @Scheduled(initialDelayString = "PT2M", fixedDelayString = "PT12H")
    void purgeDeletedPhotos() {
        jdbc.queryForList("SELECT storage_key FROM medication_images WHERE deleted_at < ?", String.class,
                java.sql.Timestamp.from(clock.instant().minus(java.time.Duration.ofDays(30)))).forEach(images::delete);
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
