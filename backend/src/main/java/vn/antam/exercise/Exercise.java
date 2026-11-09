package vn.antam.exercise;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** A recurring exercise reminder ("Đi bộ 20 phút" on Mon/Wed/Fri at 06:30). Versioned like medications. */
@Entity
@Table(name = "exercises")
public class Exercise {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "group_id", nullable = false)
    private Long groupId;

    @Column(name = "elder_user_id", nullable = false)
    private Long elderUserId;

    @Column(name = "series_id", nullable = false)
    private UUID seriesId;

    @Column(nullable = false)
    private String title;

    @Column(name = "time_of_day", nullable = false)
    private LocalTime timeOfDay;

    @Column(name = "days_of_week", nullable = false)
    private short daysOfWeek;

    @Column(name = "duration_min")
    private Short durationMin;

    private String note;

    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    @Column(name = "end_date")
    private LocalDate endDate;

    @Column(nullable = false)
    private boolean active = true;

    @Column(name = "created_by", nullable = false)
    private Long createdBy;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_by")
    private Long updatedBy;

    @Column(name = "updated_at")
    private Instant updatedAt;

    protected Exercise() {
    }

    public Exercise(Long groupId, Long elderUserId, UUID seriesId, Long createdBy, Instant now) {
        this.groupId = groupId;
        this.elderUserId = elderUserId;
        this.seriesId = seriesId;
        this.createdBy = createdBy;
        this.createdAt = now;
    }

    public void apply(String title, LocalTime time, int mask, Short durationMin, String note, LocalDate start, LocalDate end) {
        this.title = title;
        this.timeOfDay = time;
        this.daysOfWeek = (short) mask;
        this.durationMin = durationMin;
        this.note = note;
        this.startDate = start;
        this.endDate = end;
    }

    /** Time or weekdays differ: past days must keep the old plan. */
    public boolean scheduleDiffers(LocalTime time, int mask) {
        return !timeOfDay.equals(time) || daysOfWeek != mask;
    }

    public void touch(Long userId, Instant now) {
        this.updatedBy = userId;
        this.updatedAt = now;
    }

    public void closeBefore(LocalDate nextStart) {
        this.endDate = nextStart.minusDays(1);
    }

    public void deactivate() {
        this.active = false;
    }

    public Long getId() { return id; }
    public Long getGroupId() { return groupId; }
    public Long getElderUserId() { return elderUserId; }
    public UUID getSeriesId() { return seriesId; }
    public String getTitle() { return title; }
    public LocalTime getTimeOfDay() { return timeOfDay; }
    public short getDaysOfWeek() { return daysOfWeek; }
    public Short getDurationMin() { return durationMin; }
    public String getNote() { return note; }
    public LocalDate getStartDate() { return startDate; }
    public LocalDate getEndDate() { return endDate; }
    public boolean isActive() { return active; }
    public Instant getCreatedAt() { return createdAt; }
}
