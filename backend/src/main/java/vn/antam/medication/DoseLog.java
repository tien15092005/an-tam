package vn.antam.medication;

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

/** A dose that was confirmed taken, explicitly not taken, or skipped. One per medication and scheduled time. */
@Entity
@Table(name = "dose_logs")
public class DoseLog {

    public enum Status { TAKEN, NOT_TAKEN, SKIPPED }

    public enum Source { BUTTON, VOICE, CAREGIVER }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "medication_id", nullable = false)
    private Long medicationId;

    @Column(name = "elder_user_id", nullable = false)
    private Long elderUserId;

    @Column(name = "scheduled_date", nullable = false)
    private LocalDate scheduledDate;

    @Column(name = "scheduled_time", nullable = false)
    private LocalTime scheduledTime;

    @Column(name = "name_snapshot", nullable = false)
    private String nameSnapshot;

    @Column(name = "dosage_snapshot")
    private String dosageSnapshot;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Status status;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Source source;

    @Column(name = "check_result")
    private String checkResult;

    @Column(name = "client_event_id", nullable = false, unique = true)
    private UUID clientEventId;

    @Column(name = "logged_at", nullable = false)
    private Instant loggedAt;

    @Column(name = "logged_by", nullable = false)
    private Long loggedBy;

    protected DoseLog() {
    }

    public DoseLog(Medication m, LocalDate date, LocalTime time, Status status, Source source, UUID clientEventId,
                   Long loggedBy, Instant now) {
        this.medicationId = m.getId();
        this.elderUserId = m.getElderUserId();
        this.scheduledDate = date;
        this.scheduledTime = time;
        this.nameSnapshot = m.getName();
        this.dosageSnapshot = m.getDosage();
        this.status = status;
        this.source = source;
        this.clientEventId = clientEventId;
        this.loggedBy = loggedBy;
        this.loggedAt = now;
    }

    public void setCheckResult(String checkResult) {
        this.checkResult = checkResult;
    }

    public Long getId() {
        return id;
    }

    public Long getMedicationId() {
        return medicationId;
    }

    public Long getElderUserId() {
        return elderUserId;
    }

    public LocalDate getScheduledDate() {
        return scheduledDate;
    }

    public LocalTime getScheduledTime() {
        return scheduledTime;
    }

    public String getNameSnapshot() {
        return nameSnapshot;
    }

    public String getDosageSnapshot() {
        return dosageSnapshot;
    }

    public Status getStatus() {
        return status;
    }

    public Source getSource() {
        return source;
    }

    public String getCheckResult() {
        return checkResult;
    }

    public Instant getLoggedAt() {
        return loggedAt;
    }

    public Long getLoggedBy() {
        return loggedBy;
    }
}
