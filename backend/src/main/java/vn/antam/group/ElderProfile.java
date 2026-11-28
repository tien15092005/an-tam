package vn.antam.group;

import java.time.DateTimeException;
import java.time.ZoneId;

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
        this.timezone = DEFAULT_ZONE;
    }

    public static final String DEFAULT_ZONE = "Asia/Ho_Chi_Minh";

    /** True for an IANA zone id Java knows, e.g. "Asia/Ho_Chi_Minh" (not "Asia/HoChiMinh"). */
    public static boolean isValidZone(String id) {
        if (id == null || id.isBlank()) return false;
        try {
            ZoneId.of(id);
            return true;
        } catch (DateTimeException e) {
            return false;
        }
    }

    /**
     * The parent's time zone. Requests are validated, so this only falls back for bad rows saved before that
     * check existed: one bad profile must never break schedules or alerts for everyone else.
     */
    public ZoneId zone() {
        return isValidZone(timezone) ? ZoneId.of(timezone) : ZoneId.of(DEFAULT_ZONE);
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
