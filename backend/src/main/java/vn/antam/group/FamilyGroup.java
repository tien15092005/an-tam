package vn.antam.group;

import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "family_groups")
public class FamilyGroup {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(name = "schedule_version", nullable = false)
    private long scheduleVersion;

    @Column(name = "created_by", nullable = false)
    private Long createdBy;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "deleted_at")
    private Instant deletedAt;

    protected FamilyGroup() {
    }

    public FamilyGroup(String name, Long createdBy, Instant now) {
        this.name = name;
        this.createdBy = createdBy;
        this.createdAt = now;
    }

    public Long getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public long getScheduleVersion() {
        return scheduleVersion;
    }

    public boolean isDeleted() {
        return deletedAt != null;
    }

    public void rename(String name) {
        this.name = name;
    }

    /** Any schedule change: the elder's phone compares versions to know it must re-download. */
    public void bumpScheduleVersion() {
        this.scheduleVersion++;
    }

    public void delete(Instant now) {
        this.deletedAt = now;
    }
}
