package vn.antam.group;

import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** A one-time code: pairs an elder's phone (ELDER_DEVICE) or lets a caregiver join (MEMBER). */
@Entity
@Table(name = "invites")
public class Invite {

    public enum Kind { ELDER_DEVICE, MEMBER }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Kind kind;

    @Column(name = "code_hash", nullable = false)
    private String codeHash;

    @Column(name = "group_id", nullable = false)
    private Long groupId;

    @Column(name = "elder_user_id")
    private Long elderUserId;

    @Column(name = "created_by", nullable = false)
    private Long createdBy;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "used_at")
    private Instant usedAt;

    @Column(name = "used_by")
    private Long usedBy;

    protected Invite() {
    }

    public Invite(Kind kind, String codeHash, Long groupId, Long elderUserId, Long createdBy, Instant now, Instant expiresAt) {
        this.kind = kind;
        this.codeHash = codeHash;
        this.groupId = groupId;
        this.elderUserId = elderUserId;
        this.createdBy = createdBy;
        this.createdAt = now;
        this.expiresAt = expiresAt;
    }

    public boolean isUsable(Instant now) {
        return usedAt == null && now.isBefore(expiresAt);
    }

    public void markUsed(Long userId, Instant now) {
        this.usedAt = now;
        this.usedBy = userId;
    }

    public void expire(Instant now) {
        if (usedAt == null) this.expiresAt = now;
    }

    public Kind getKind() {
        return kind;
    }

    public Long getGroupId() {
        return groupId;
    }

    public Long getElderUserId() {
        return elderUserId;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }
}
