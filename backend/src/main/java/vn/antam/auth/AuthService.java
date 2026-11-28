package vn.antam.auth;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;

import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import vn.antam.common.ApiException;
import vn.antam.group.Invite;
import vn.antam.group.InviteRepository;
import vn.antam.user.AccountType;
import vn.antam.user.User;
import vn.antam.user.UserRepository;

@Service
public class AuthService {

    private static final Duration WINDOW = Duration.ofMinutes(10);
    private static final String PAIR_FAILURES = "pair:fail:global";

    private final UserRepository users;
    private final InviteRepository invites;
    private final PasswordEncoder passwordEncoder;
    private final TokenService tokens;
    private final Secrets secrets;
    private final AttemptLimiter limiter;
    private final Clock clock;

    public AuthService(UserRepository users, InviteRepository invites, PasswordEncoder passwordEncoder,
                       TokenService tokens, Secrets secrets, AttemptLimiter limiter, Clock clock) {
        this.users = users;
        this.invites = invites;
        this.passwordEncoder = passwordEncoder;
        this.tokens = tokens;
        this.secrets = secrets;
        this.limiter = limiter;
        this.clock = clock;
    }

    @Transactional
    public TokenService.TokenPair register(String email, String password, String displayName, String phone, String deviceName) {
        String normalized = email.trim().toLowerCase(java.util.Locale.ROOT);
        if (users.existsByEmailIgnoreCase(normalized)) {
            throw ApiException.conflict("email_taken", "Email này đã được đăng ký.");
        }
        User user = users.save(User.caregiver(normalized, passwordEncoder.encode(password), displayName.trim(), blankToNull(phone), clock.instant()));
        return tokens.issue(user, deviceName);
    }

    @Transactional
    public TokenService.TokenPair login(String email, String password, String deviceName, String ip) {
        String normalized = email.trim().toLowerCase(java.util.Locale.ROOT);
        limiter.check("login:ip:" + ip, 20, WINDOW);
        limiter.check("login:email:" + normalized, 8, WINDOW);
        User user = users.findByEmailIgnoreCase(normalized)
                .filter(u -> u.getAccountType() != AccountType.ELDER)
                .filter(u -> passwordEncoder.matches(password, u.getPasswordHash()))
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "bad_credentials", "Sai email hoặc mật khẩu."));
        if (user.isDisabled()) throw new ApiException(HttpStatus.FORBIDDEN, "account_disabled", "Tài khoản đã bị khóa.");
        limiter.reset("login:email:" + normalized);
        return tokens.issue(user, deviceName);
    }

    /**
     * Pairs an elder's phone with a 6-digit code. Codes are looked up by HMAC, so a wrong guess matches
     * nothing; brute force is held back per real client address (see ClientIp), by a global brake on wrong codes,
     * and by the 15-minute expiry.
     */
    @Transactional
    public TokenService.TokenPair pairElderDevice(String code, String deviceName, String ip) {
        limiter.check("pair:ip:" + ip, 10, WINDOW);
        // A system-wide brake on wrong codes only (right codes never count), so ordinary pairing cannot be
        // blocked by someone sending junk: it takes 1,000 wrong guesses in 10 minutes from many addresses.
        limiter.requireUnder(PAIR_FAILURES, 1000, WINDOW);
        Instant now = clock.instant();
        Invite invite = invites.findFirstByKindAndCodeHashAndUsedAtIsNullAndExpiresAtAfter(
                        Invite.Kind.ELDER_DEVICE, secrets.hashCode(code), now)
                .orElseThrow(() -> {
                    limiter.record(PAIR_FAILURES);
                    return ApiException.badRequest("invalid_code", "Mã không đúng hoặc đã hết hạn. Nhờ con tạo mã mới.");
                });
        User elder = users.findById(invite.getElderUserId()).orElseThrow(() -> ApiException.notFound("hồ sơ"));
        if (elder.isDisabled()) throw new ApiException(HttpStatus.FORBIDDEN, "account_disabled", "Tài khoản đã bị khóa.");
        invite.markUsed(elder.getId(), now);
        // Only one phone per elder: pairing a new one signs out the old one.
        tokens.revokeAll(elder.getId());
        return tokens.issue(elder, deviceName);
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
