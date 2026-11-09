package vn.antam.notification;

import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** One notification for one person, written with the event and delivered later (plan §10). */
@Entity
@Table(name = "notification_outbox")
public class OutboxEntry {

    public enum Status { PENDING, SENT, NO_DEVICE, DISABLED, FAILED }

    public static final int MAX_ATTEMPTS = 5;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "dedupe_key", nullable = false, unique = true)
    private String dedupeKey;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(nullable = false)
    private String kind;

    @Column(name = "group_id")
    private Long groupId;

    @Column(name = "ref_id")
    private Long refId;

    private String title;

    private String body;

    @Column(nullable = false)
    private boolean urgent;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Status status = Status.PENDING;

    @Column(nullable = false)
    private int attempts;

    @Column(name = "last_error")
    private String lastError;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "sent_at")
    private Instant sentAt;

    protected OutboxEntry() {
    }

    public OutboxEntry(String dedupeKey, Long userId, String kind, Long groupId, Long refId, String title, String body,
                       boolean urgent, Instant now) {
        this.dedupeKey = dedupeKey;
        this.userId = userId;
        this.kind = kind;
        this.groupId = groupId;
        this.refId = refId;
        this.title = title;
        this.body = body;
        this.urgent = urgent;
        this.createdAt = now;
    }

    public void finish(Status status, Instant now) {
        this.status = status;
        this.sentAt = now;
    }

    public void failed(String error, Instant now) {
        this.attempts++;
        this.lastError = error == null ? null : error.substring(0, Math.min(error.length(), 200));
        if (attempts >= MAX_ATTEMPTS) finish(Status.FAILED, now);
    }

    public Long getId() { return id; }
    public String getDedupeKey() { return dedupeKey; }
    public Long getUserId() { return userId; }
    public String getKind() { return kind; }
    public Long getGroupId() { return groupId; }
    public Long getRefId() { return refId; }
    public String getTitle() { return title; }
    public String getBody() { return body; }
    public boolean isUrgent() { return urgent; }
    public Status getStatus() { return status; }
    public int getAttempts() { return attempts; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getSentAt() { return sentAt; }
}
