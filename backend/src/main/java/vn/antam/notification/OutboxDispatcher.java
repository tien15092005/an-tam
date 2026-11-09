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
import org.springframework.transaction.annotation.Transactional;

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

    /** @return how many entries were closed (sent or given up) */
    @Transactional
    public int dispatch() {
        List<OutboxEntry> batch = outbox.findTop50ByStatusOrderByCreatedAt(OutboxEntry.Status.PENDING);
        int closed = 0;
        for (OutboxEntry e : batch) {
            Instant now = clock.instant();
            if (!sender.enabled()) {
                e.finish(OutboxEntry.Status.DISABLED, now);
                closed++;
                continue;
            }
            List<Device> targets = devices.findByUserId(e.getUserId());
            if (targets.isEmpty()) {
                e.finish(OutboxEntry.Status.NO_DEVICE, now);
                closed++;
                continue;
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
                closed++;
            } else if (retry) {
                e.failed("push service unavailable", now);
                if (e.getStatus() != OutboxEntry.Status.PENDING) closed++;
            } else {
                e.finish(OutboxEntry.Status.NO_DEVICE, now);
                closed++;
            }
        }
        outbox.saveAll(batch);
        if (closed > 0) log.debug("Outbox: closed {} of {}", closed, batch.size());
        return closed;
    }

    private static Map<String, String> data(OutboxEntry e) {
        Map<String, String> d = new HashMap<>();
        d.put("kind", e.getKind());
        if (e.getGroupId() != null) d.put("groupId", e.getGroupId().toString());
        if (e.getRefId() != null) d.put("refId", e.getRefId().toString());
        return d;
    }
}
