package vn.antam.auth;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import vn.antam.common.ApiException;
import vn.antam.user.AccountType;
import vn.antam.user.User;
import vn.antam.user.UserRepository;

/** Issues short-lived access tokens (JWT) and rotating refresh tokens. */
@Service
public class TokenService {

    public record TokenPair(String accessToken, String refreshToken, long expiresInSeconds) {
    }

    private final JwtEncoder jwtEncoder;
    private final RefreshTokenRepository refreshTokens;
    private final UserRepository users;
    private final Secrets secrets;
    private final Clock clock;
    private final Duration accessTtl;
    private final Duration caregiverRefreshTtl;
    private final Duration elderRefreshTtl;

    public TokenService(JwtEncoder jwtEncoder, RefreshTokenRepository refreshTokens, UserRepository users,
                        Secrets secrets, Clock clock,
                        @Value("${antam.jwt.access-ttl:15m}") Duration accessTtl,
                        @Value("${antam.jwt.refresh-ttl:30d}") Duration caregiverRefreshTtl,
                        @Value("${antam.jwt.elder-refresh-ttl:365d}") Duration elderRefreshTtl) {
        this.jwtEncoder = jwtEncoder;
        this.refreshTokens = refreshTokens;
        this.users = users;
        this.secrets = secrets;
        this.clock = clock;
        this.accessTtl = accessTtl;
        this.caregiverRefreshTtl = caregiverRefreshTtl;
        this.elderRefreshTtl = elderRefreshTtl;
    }

    @Transactional
    public TokenPair issue(User user, String deviceName) {
        Instant now = clock.instant();
        // Elders pair once and should not be logged out for a year; caregivers re-login monthly.
        Duration refreshTtl = user.getAccountType() == AccountType.ELDER ? elderRefreshTtl : caregiverRefreshTtl;
        String refresh = secrets.refreshToken();
        refreshTokens.save(new RefreshToken(user.getId(), secrets.hashToken(refresh), deviceName, now, now.plus(refreshTtl)));
        return new TokenPair(accessToken(user, now), refresh, accessTtl.toSeconds());
    }

    /**
     * Swaps a refresh token for a new pair. Presenting a token that was already exchanged means it was
     * copied and replayed, so every session of that user is revoked. A token revoked for other reasons
     * (logout, a new phone paired) is simply refused.
     */
    @Transactional(noRollbackFor = ApiException.class)
    public TokenPair refresh(String refreshToken) {
        Instant now = clock.instant();
        RefreshToken current = refreshTokens.findByTokenHash(secrets.hashToken(refreshToken == null ? "" : refreshToken))
                .orElseThrow(TokenService::invalidSession);
        if (current.wasRotated()) {
            refreshTokens.revokeAllForUser(current.getUserId(), now);
            throw invalidSession();
        }
        if (current.isRevoked()) throw invalidSession();
        if (current.isExpired(now)) throw invalidSession();
        User user = users.findById(current.getUserId()).orElseThrow(TokenService::invalidSession);
        if (user.isDisabled()) throw new ApiException(HttpStatus.FORBIDDEN, "account_disabled", "Tài khoản đã bị khóa.");
        current.rotate(now);
        return issue(user, current.getDeviceName());
    }

    @Transactional
    public void revoke(String refreshToken) {
        refreshTokens.findByTokenHash(secrets.hashToken(refreshToken == null ? "" : refreshToken))
                .ifPresent(t -> t.revoke(clock.instant()));
    }

    @Transactional
    public void revokeAll(Long userId) {
        refreshTokens.revokeAllForUser(userId, clock.instant());
    }

    private String accessToken(User user, Instant now) {
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer("an-tam")
                .subject(String.valueOf(user.getId()))
                .issuedAt(now)
                .expiresAt(now.plus(accessTtl))
                .claim("typ", user.getAccountType().name())
                .build();
        return jwtEncoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }

    private static ApiException invalidSession() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "invalid_session", "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.");
    }
}
