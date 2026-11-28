package vn.antam.user;

import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(name = "account_type", nullable = false)
    private AccountType accountType;

    private String email;

    @Column(name = "password_hash")
    private String passwordHash;

    @Column(name = "display_name", nullable = false)
    private String displayName;

    private String phone;

    @Column(nullable = false)
    private boolean disabled;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected User() {
    }

    public static User caregiver(String email, String passwordHash, String displayName, String phone, Instant now) {
        User u = new User();
        u.accountType = AccountType.CAREGIVER;
        u.email = email;
        u.passwordHash = passwordHash;
        u.displayName = displayName;
        u.phone = phone;
        u.createdAt = now;
        return u;
    }

    /** System admin (plan §10): created from ADMIN_EMAIL / ADMIN_PASSWORD at start-up, never by sign-up. */
    public static User admin(String email, String passwordHash, Instant now) {
        User u = new User();
        u.accountType = AccountType.SYSTEM_ADMIN;
        u.email = email;
        u.passwordHash = passwordHash;
        u.displayName = "Quản trị";
        u.createdAt = now;
        return u;
    }

    /** "Xóa tài khoản": personal data removed, the row kept so history and foreign keys stay valid. */
    public void anonymize() {
        this.email = null;
        this.passwordHash = null;
        this.phone = null;
        this.displayName = "Tài khoản đã xóa";
        this.disabled = true;
    }

    public void setDisabled(boolean disabled) {
        this.disabled = disabled;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public static User elder(String displayName, String phone, Instant now) {
        User u = new User();
        u.accountType = AccountType.ELDER;
        u.displayName = displayName;
        u.phone = phone;
        u.createdAt = now;
        return u;
    }

    public Long getId() {
        return id;
    }

    public AccountType getAccountType() {
        return accountType;
    }

    public String getEmail() {
        return email;
    }

    public void changePassword(String passwordHash) {
        this.passwordHash = passwordHash;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public String getDisplayName() {
        return displayName;
    }

    public String getPhone() {
        return phone;
    }

    public boolean isDisabled() {
        return disabled;
    }

    public void rename(String displayName, String phone) {
        this.displayName = displayName;
        this.phone = phone;
    }
}
