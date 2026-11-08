package vn.antam.group;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** Extra details about an elder account; call_name is how the voice reminder addresses them. */
@Entity
@Table(name = "elder_profiles")
public class ElderProfile {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @Column(name = "group_id", nullable = false)
    private Long groupId;

    @Column(name = "call_name", nullable = false)
    private String callName;

    @Column(name = "birth_year")
    private Short birthYear;

    private String phone;

    @Column(name = "health_note")
    private String healthNote;

    @Column(nullable = false)
    private String timezone;

    protected ElderProfile() {
    }

    public ElderProfile(Long userId, Long groupId) {
        this.userId = userId;
        this.groupId = groupId;
        this.timezone = "Asia/Ho_Chi_Minh";
    }

    public void update(String callName, Short birthYear, String phone, String healthNote, String timezone) {
        this.callName = callName;
        this.birthYear = birthYear;
        this.phone = phone;
        this.healthNote = healthNote;
        if (timezone != null && !timezone.isBlank()) this.timezone = timezone;
    }

    public Long getUserId() {
        return userId;
    }

    public Long getGroupId() {
        return groupId;
    }

    public String getCallName() {
        return callName;
    }

    public Short getBirthYear() {
        return birthYear;
    }

    public String getPhone() {
        return phone;
    }

    public String getHealthNote() {
        return healthNote;
    }

    public String getTimezone() {
        return timezone;
    }
}
