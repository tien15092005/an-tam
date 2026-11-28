package vn.antam.auth;

import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** A long-lived session on one device. Only the SHA-256 of the token is stored. */
@Entity
@Table(name = "refresh_tokens")
public class RefreshToken {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "token_hash", nullable = false, unique = true)
    private String tokenHash;

    @Column(name = "device_name")
    private String deviceName;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "revoked_at")
    private Instant revokedAt;

    @Column(name = "rotated_at")
    private Instant rotatedAt;

    /** The token this one was exchanged for, so a lost refresh reply can be recognised (see TokenService). */
    @Column(name = "replaced_by")
    private Long replacedBy;

    protected RefreshToken() {
    }

    public RefreshToken(Long userId, String tokenHash, String deviceName, Instant now, Instant expiresAt) {
        this.userId = userId;
        this.tokenHash = tokenHash;
        this.deviceName = deviceName;
        this.createdAt = now;
        this.expiresAt = expiresAt;
    }

    public Long getUserId() {
        return userId;
    }

    public String getDeviceName() {
        return deviceName;
    }

    public boolean isRevoked() {
        return revokedAt != null;
    }

    public boolean isExpired(Instant now) {
        return !now.isBefore(expiresAt);
    }

    public boolean wasRotated() {
        return rotatedAt != null;
    }

    public void revoke(Instant now) {
        if (revokedAt == null) revokedAt = now;
    }

    public Instant getRotatedAt() {
        return rotatedAt;
    }

    public Long getReplacedBy() {
        return replacedBy;
    }

    public Long getId() {
        return id;
    }

    /** Exchanged for {@code next} during refresh. */
    public void rotate(Instant now, Long next) {
        if (rotatedAt == null) rotatedAt = now;
        replacedBy = next;
        revoke(now);
    }
}
