package vn.antam.exercise;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import vn.antam.medication.DoseLog;

/** "TÔI ĐI TẬP ĐÂY" for one exercise on one day. */
@Entity
@Table(name = "exercise_logs")
public class ExerciseLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "exercise_id", nullable = false)
    private Long exerciseId;

    @Column(name = "elder_user_id", nullable = false)
    private Long elderUserId;

    @Column(name = "scheduled_date", nullable = false)
    private LocalDate scheduledDate;

    @Column(name = "title_snapshot", nullable = false)
    private String titleSnapshot;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private DoseLog.Source source;

    @Column(name = "client_event_id", nullable = false, unique = true)
    private UUID clientEventId;

    @Column(name = "logged_at", nullable = false)
    private Instant loggedAt;

    @Column(name = "logged_by", nullable = false)
    private Long loggedBy;

    protected ExerciseLog() {
    }

    public ExerciseLog(Exercise e, LocalDate date, DoseLog.Source source, UUID clientEventId, Long by, Instant at) {
        this.exerciseId = e.getId();
        this.elderUserId = e.getElderUserId();
        this.scheduledDate = date;
        this.titleSnapshot = e.getTitle();
        this.source = source;
        this.clientEventId = clientEventId;
        this.loggedBy = by;
        this.loggedAt = at;
    }

    public Long getId() { return id; }
    public Long getExerciseId() { return exerciseId; }
    public Long getElderUserId() { return elderUserId; }
    public LocalDate getScheduledDate() { return scheduledDate; }
    public String getTitleSnapshot() { return titleSnapshot; }
    public DoseLog.Source getSource() { return source; }
    public Instant getLoggedAt() { return loggedAt; }
    public Long getLoggedBy() { return loggedBy; }
}
