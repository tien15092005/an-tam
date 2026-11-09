package vn.antam.notification;

import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** An app install that can receive pushes (its FCM registration token). */
@Entity
@Table(name = "devices")
public class Device {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "fcm_token", nullable = false, unique = true)
    private String fcmToken;

    @Column(nullable = false)
    private String platform;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "last_seen_at", nullable = false)
    private Instant lastSeenAt;

    protected Device() {
    }

    public Device(Long userId, String fcmToken, String platform, Instant now) {
        this.userId = userId;
        this.fcmToken = fcmToken;
        this.platform = platform;
        this.createdAt = now;
        this.lastSeenAt = now;
    }

    /** The same install signed in again (maybe as someone else). */
    public void seen(Long userId, String platform, Instant now) {
        this.userId = userId;
        this.platform = platform;
        this.lastSeenAt = now;
    }

    public Long getId() { return id; }
    public Long getUserId() { return userId; }
    public String getFcmToken() { return fcmToken; }
    public String getPlatform() { return platform; }
}
