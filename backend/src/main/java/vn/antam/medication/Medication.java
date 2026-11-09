package vn.antam.medication;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;

@Entity
@Table(name = "medications")
public class Medication {

    public enum Source { MANUAL, OCR_PRESCRIPTION, OCR_PACKAGE, OCR_INVOICE }

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
    private String name;

    private String strength;
    private String dosage;
    private String note;
    private String shape;
    private String color;
    private String imprint;

    @Column(name = "pill_description")
    private String pillDescription;

    @Column(name = "days_of_week", nullable = false)
    private short daysOfWeek;

    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    @Column(name = "end_date")
    private LocalDate endDate;

    @Column(nullable = false)
    private boolean active;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Source source;

    @Column(name = "created_by", nullable = false)
    private Long createdBy;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_by")
    private Long updatedBy;

    @Column(name = "updated_at")
    private Instant updatedAt;

    @OneToMany(mappedBy = "medication", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.EAGER)
    @OrderBy("timeOfDay")
    private List<MedicationTime> times = new ArrayList<>();

    protected Medication() {
    }

    public Medication(Long groupId, Long elderUserId, UUID seriesId, Long createdBy, Instant now) {
        this.groupId = groupId;
        this.elderUserId = elderUserId;
        this.seriesId = seriesId;
        this.createdBy = createdBy;
        this.createdAt = now;
        this.active = true;
        this.source = Source.MANUAL;
    }

    /** Applies every editable field (full replace). */
    public void apply(MedicationFields f) {
        this.name = f.name();
        this.strength = f.strength();
        this.dosage = f.dosage();
        this.note = f.note();
        this.shape = f.shape();
        this.color = f.color();
        this.imprint = f.imprint();
        this.pillDescription = f.pillDescription();
        this.daysOfWeek = f.daysOfWeekMask();
        this.startDate = f.startDate();
        this.endDate = f.endDate();
        if (f.source() != null) this.source = f.source();
        // Keep unchanged rows: Hibernate inserts before it deletes orphans, so clear-and-re-add of the
        // same time would trip the (medication_id, time_of_day) unique constraint.
        this.times.removeIf(t -> !f.times().contains(t.getTimeOfDay()));
        List<LocalTime> kept = this.times.stream().map(MedicationTime::getTimeOfDay).toList();
        for (LocalTime t : f.times()) if (!kept.contains(t)) this.times.add(new MedicationTime(this, t));
    }

    public void touch(Long userId, Instant now) {
        this.updatedBy = userId;
        this.updatedAt = now;
    }

    /** Ends this version the day before {@code nextStart}; the new version takes over from there. */
    public void closeBefore(LocalDate nextStart) {
        this.endDate = nextStart.minusDays(1);
    }

    public void deactivate() {
        this.active = false;
    }

    public List<LocalTime> timeList() {
        return times.stream().map(MedicationTime::getTimeOfDay).sorted().toList();
    }

    public Long getId() { return id; }
    public Long getGroupId() { return groupId; }
    public Long getElderUserId() { return elderUserId; }
    public UUID getSeriesId() { return seriesId; }
    public String getName() { return name; }
    public String getStrength() { return strength; }
    public String getDosage() { return dosage; }
    public String getNote() { return note; }
    public String getShape() { return shape; }
    public String getColor() { return color; }
    public String getImprint() { return imprint; }
    public String getPillDescription() { return pillDescription; }
    public short getDaysOfWeek() { return daysOfWeek; }
    public LocalDate getStartDate() { return startDate; }
    public LocalDate getEndDate() { return endDate; }
    public boolean isActive() { return active; }
    public Source getSource() { return source; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
