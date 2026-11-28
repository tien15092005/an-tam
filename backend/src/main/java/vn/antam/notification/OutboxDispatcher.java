package vn.antam.notification;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.data.domain.Limit;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;

/**
 * Sends what the outbox holds. Runs every few seconds and once at start-up, so notifications queued
 * while the laptop was off go out as soon as it is back (plan §10: "quét bù").
 */
@Component
public class OutboxDispatcher {

    private static final Logger log = LoggerFactory.getLogger(OutboxDispatcher.class);

    private final OutboxRepository outbox;
    private final DeviceRepository devices;
    private final PushSender sender;
    private final Clock clock;
    private final Timer latency;

    public OutboxDispatcher(OutboxRepository outbox, DeviceRepository devices, PushSender sender, Clock clock,
                            MeterRegistry meters) {
        this.outbox = outbox;
        this.devices = devices;
        this.sender = sender;
        this.clock = clock;
        // Event queued -> handed to FCM. Shown at /actuator/metrics/antam.notifications.latency.
        this.latency = Timer.builder("antam.notifications.latency").description("Outbox entry created to sent")
                .register(meters);
    }

    /**
     * Each entry is sent and saved on its own (no transaction around the batch): a push that went out is never
     * rolled back by a later failure, and one entry that throws is retried later instead of blocking the rest.
     *
     * @return how many entries were looked at (a full batch means more may be waiting)
     */
    public int dispatch() {
        List<OutboxEntry> batch = outbox.findDue(clock.instant(), Limit.of(BATCH));
        int closed = 0;
        for (OutboxEntry e : batch) {
            Instant now = clock.instant();
            try {
                deliver(e, now);
            } catch (RuntimeException ex) {
                log.warn("Outbox entry {} failed, will retry: {}", e.getId(), ex.toString());
                e.failed(ex.getClass().getSimpleName() + ": " + ex.getMessage(), now);
            }
            outbox.save(e);
            if (e.getStatus() != OutboxEntry.Status.PENDING) closed++;
        }
        if (closed > 0) log.debug("Outbox: closed {} of {}", closed, batch.size());
        return batch.size();
    }

    static final int BATCH = 50;

    private void deliver(OutboxEntry e, Instant now) {
        if (!sender.enabled()) {
            e.finish(OutboxEntry.Status.DISABLED, now);
            return;
        }
        List<Device> targets = devices.findByUserId(e.getUserId());
        if (targets.isEmpty()) {
            e.finish(OutboxEntry.Status.NO_DEVICE, now);
            return;
        }
        boolean sent = false;
        boolean retry = false;
        for (Device d : targets) {
            switch (sender.send(d.getFcmToken(), e.getTitle(), e.getBody(), data(e), e.isUrgent())) {
                case SENT -> sent = true;
                case INVALID_TOKEN -> devices.delete(d);
                case RETRY -> retry = true;
            }
        }
        if (sent) {
            e.finish(OutboxEntry.Status.SENT, now);
            latency.record(Duration.between(e.getCreatedAt(), now));
        } else if (retry) {
            e.failed("push service unavailable", now);
        } else {
            e.finish(OutboxEntry.Status.NO_DEVICE, now);
        }
    }

    private static Map<String, String> data(OutboxEntry e) {
        Map<String, String> d = new HashMap<>();
        d.put("kind", e.getKind());
        if (e.getGroupId() != null) d.put("groupId", e.getGroupId().toString());
        if (e.getRefId() != null) d.put("refId", e.getRefId().toString());
        return d;
    }
}
