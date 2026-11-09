package vn.antam.care;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** Something a caregiver should look at: a problem the elder reported, or (Phase 6) a dose not confirmed. */
@Entity
@Table(name = "alerts")
public class Alert {

    public enum Kind { UNWELL, LOST_MEDICINE, OUT_OF_MEDICINE, UNSURE_PILL, OTHER_ISSUE, NOT_CONFIRMED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "group_id", nullable = false)
    private Long groupId;

    @Column(name = "elder_user_id", nullable = false)
    private Long elderUserId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Kind kind;

    @Column(name = "dose_log_id")
    private Long doseLogId;

    @Column(name = "medication_id")
    private Long medicationId;

    @Column(name = "medication_names")
    private String medicationNames;

    @Column(name = "scheduled_date")
    private LocalDate scheduledDate;

    @Column(name = "scheduled_time")
    private LocalTime scheduledTime;

    @Column(name = "client_event_id", unique = true)
    private UUID clientEventId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "resolved_at")
    private Instant resolvedAt;

    @Column(name = "resolved_by")
    private Long resolvedBy;

    protected Alert() {
    }

    public Alert(Long groupId, Long elderUserId, Kind kind, UUID clientEventId, Instant createdAt) {
        this.groupId = groupId;
        this.elderUserId = elderUserId;
        this.kind = kind;
        this.clientEventId = clientEventId;
        this.createdAt = createdAt;
    }

    public void aboutDose(Long doseLogId, Long medicationId, String medicationNames, LocalDate date, LocalTime time) {
        this.doseLogId = doseLogId;
        this.medicationId = medicationId;
        this.medicationNames = medicationNames;
        this.scheduledDate = date;
        this.scheduledTime = time;
    }

    public void resolve(Long by, Instant at) {
        if (resolvedAt != null) return;
        this.resolvedBy = by;
        this.resolvedAt = at;
    }

    public Long getId() { return id; }
    public Long getGroupId() { return groupId; }
    public Long getElderUserId() { return elderUserId; }
    public Kind getKind() { return kind; }
    public Long getDoseLogId() { return doseLogId; }
    public Long getMedicationId() { return medicationId; }
    public String getMedicationNames() { return medicationNames; }
    public LocalDate getScheduledDate() { return scheduledDate; }
    public LocalTime getScheduledTime() { return scheduledTime; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getResolvedAt() { return resolvedAt; }
    public Long getResolvedBy() { return resolvedBy; }
}
