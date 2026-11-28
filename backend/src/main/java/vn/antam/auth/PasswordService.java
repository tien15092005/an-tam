package vn.antam.auth;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Locale;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import vn.antam.common.ApiException;
import vn.antam.group.GroupMember;
import vn.antam.group.GroupMemberRepository;
import vn.antam.group.GroupRole;
import vn.antam.user.AccountType;
import vn.antam.user.User;
import vn.antam.user.UserRepository;

/**
 * Changing a password, and resetting a forgotten one without e-mail: another child in the same family (who
 * knows the person) creates a one-time code and passes it on by phone or Zalo. The code is stored as HMAC only,
 * works once, for 15 minutes, for that one account.
 */
@Service
public class PasswordService {

    static final Duration RESET_CODE_TTL = Duration.ofMinutes(15);
    private static final Duration WINDOW = Duration.ofMinutes(10);
    private static final List<GroupRole> CAREGIVERS = List.of(GroupRole.OWNER, GroupRole.MEMBER);

    public record ResetCode(String code, Instant expiresAt) {
    }

    private final UserRepository users;
    private final GroupMemberRepository members;
    private final PasswordEncoder encoder;
    private final TokenService tokens;
    private final Secrets secrets;
    private final AttemptLimiter limiter;
    private final JdbcTemplate jdbc;
    private final Clock clock;

    public PasswordService(UserRepository users, GroupMemberRepository members, PasswordEncoder encoder, TokenService tokens,
                           Secrets secrets, AttemptLimiter limiter, JdbcTemplate jdbc, Clock clock) {
        this.users = users;
        this.members = members;
        this.encoder = encoder;
        this.tokens = tokens;
        this.secrets = secrets;
        this.limiter = limiter;
        this.jdbc = jdbc;
        this.clock = clock;
    }

    /** Needs the current password. Every other session of the account ends; this phone gets a fresh pair. */
    @Transactional
    public TokenService.TokenPair change(Long userId, String current, String next, String deviceName) {
        limiter.check("password-change:" + userId, 8, WINDOW);
        User user = users.findById(userId).filter(u -> u.getAccountType() != AccountType.ELDER)
                .orElseThrow(() -> ApiException.forbidden("Chức năng này dành cho tài khoản người con."));
        if (!AuthService.fitsBcrypt(current) || !encoder.matches(current, user.getPasswordHash())) {
            throw ApiException.badRequest("wrong_password", "Mật khẩu hiện tại không đúng.");
        }
        return setPassword(user, next, deviceName);
    }

    /** A child creates a reset code for a sibling in a family they share. Older unused codes for them stop working. */
    @Transactional
    public ResetCode createResetCode(Long byUserId, Long groupId, Long targetUserId) {
        limiter.check("password-reset-create:" + byUserId, 10, Duration.ofHours(1));
        boolean callerIn = members.findByGroupIdAndUserIdAndLeftAtIsNull(groupId, byUserId)
                .map(GroupMember::getRole).filter(CAREGIVERS::contains).isPresent();
        if (!callerIn) throw ApiException.notFound("nhóm");
        if (byUserId.equals(targetUserId)) {
            throw ApiException.badRequest("cannot_reset_self", "Hãy dùng chức năng Đổi mật khẩu cho tài khoản của bạn.");
        }
        members.findByGroupIdAndUserIdAndLeftAtIsNull(groupId, targetUserId)
                .map(GroupMember::getRole).filter(CAREGIVERS::contains)
                .orElseThrow(() -> ApiException.notFound("người con trong nhóm"));
        Instant now = clock.instant();
        jdbc.update("UPDATE password_resets SET expires_at = ? WHERE user_id = ? AND used_at IS NULL AND expires_at > ?",
                Timestamp.from(now), targetUserId, Timestamp.from(now));
        String code = secrets.inviteCode();
        Instant expires = now.plus(RESET_CODE_TTL);
        jdbc.update("INSERT INTO password_resets (user_id, code_hash, created_by, created_at, expires_at) VALUES (?, ?, ?, ?, ?)",
                targetUserId, secrets.hashCode(code), byUserId, Timestamp.from(now), Timestamp.from(expires));
        return new ResetCode(code, expires);
    }

    /** Email + code + new password. Signs in on this phone and ends every other session. */
    @Transactional
    public TokenService.TokenPair reset(String email, String code, String next, String deviceName, String ip) {
        String normalized = email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
        limiter.check("password-reset:ip:" + ip, 10, WINDOW);
        limiter.check("password-reset:email:" + normalized, 10, WINDOW);
        ApiException invalid = ApiException.badRequest("invalid_code", "Mã không đúng hoặc đã hết hạn. Nhờ anh chị em tạo mã mới.");
        User user = users.findByEmailIgnoreCase(normalized).filter(u -> u.getAccountType() == AccountType.CAREGIVER)
                .orElseThrow(() -> invalid);
        Instant now = clock.instant();
        int used = jdbc.update("""
                UPDATE password_resets SET used_at = ?
                WHERE user_id = ? AND code_hash = ? AND used_at IS NULL AND expires_at > ?
                """, Timestamp.from(now), user.getId(), secrets.hashCode(code == null ? "" : code), Timestamp.from(now));
        if (used == 0) throw invalid;
        if (user.isDisabled()) throw new ApiException(HttpStatus.FORBIDDEN, "account_disabled", "Tài khoản đã bị khóa.");
        limiter.reset("password-reset:email:" + normalized);
        return setPassword(user, next, deviceName);
    }

    private TokenService.TokenPair setPassword(User user, String next, String deviceName) {
        AuthService.requirePasswordFits(next);
        if (next == null || next.length() < 8) {
            throw ApiException.badRequest("password_too_short", "Mật khẩu cần ít nhất 8 ký tự.");
        }
        user.changePassword(encoder.encode(next));
        tokens.revokeAll(user.getId());
        return tokens.issue(user, deviceName);
    }
}
