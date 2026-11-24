package vn.antam.admin;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import vn.antam.auth.CurrentUser;
import vn.antam.auth.TokenService;
import vn.antam.common.ApiException;
import vn.antam.user.AccountType;
import vn.antam.user.User;
import vn.antam.user.UserRepository;

/**
 * System admin (plan §10): totals, account search, lock / unlock. Deliberately no endpoint here reads
 * medicines, photos or dose history, and admins are not group members, so the group endpoints answer 404.
 */
@RestController
@RequestMapping("/api/admin")
public class AdminController {

    public record Stats(Map<String, Long> usersByType, long groups, long openAlerts, long alertsLast7Days,
                        long disabledUsers, Map<String, Long> notificationsByStatus) {
    }

    public record UserRow(Long id, AccountType accountType, String displayName, String email, boolean disabled,
                          Instant createdAt, long groups) {
    }

    private final UserRepository users;
    private final JdbcTemplate jdbc;
    private final TokenService tokens;
    private final Clock clock;

    public AdminController(UserRepository users, JdbcTemplate jdbc, TokenService tokens, Clock clock) {
        this.users = users;
        this.jdbc = jdbc;
        this.tokens = tokens;
        this.clock = clock;
    }

    @GetMapping("/stats")
    public Stats stats(@CurrentUser Long me) {
        requireAdmin(me);
        Map<String, Long> byType = new java.util.TreeMap<>();
        jdbc.query("SELECT account_type, count(*) FROM users GROUP BY account_type",
                rs -> { byType.put(rs.getString(1), rs.getLong(2)); });
        Map<String, Long> outbox = new java.util.TreeMap<>();
        jdbc.query("SELECT status, count(*) FROM notification_outbox GROUP BY status",
                rs -> { outbox.put(rs.getString(1), rs.getLong(2)); });
        return new Stats(byType,
                count("SELECT count(*) FROM family_groups WHERE deleted_at IS NULL"),
                count("SELECT count(*) FROM alerts WHERE resolved_at IS NULL"),
                jdbc.queryForObject("SELECT count(*) FROM alerts WHERE created_at >= ?", Long.class,
                        java.sql.Timestamp.valueOf(LocalDate.now(clock).minusDays(7).atStartOfDay())),
                count("SELECT count(*) FROM users WHERE disabled"),
                outbox);
    }

    /** Search by name or email; at most 50 rows. */
    @GetMapping("/users")
    public List<UserRow> search(@CurrentUser Long me, @RequestParam(defaultValue = "") String q) {
        requireAdmin(me);
        String like = "%" + q.trim().toLowerCase().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%";
        return jdbc.query("""
                SELECT u.id, u.account_type, u.display_name, u.email, u.disabled, u.created_at,
                       (SELECT count(*) FROM group_members m WHERE m.user_id = u.id AND m.left_at IS NULL) AS groups
                FROM users u
                WHERE lower(u.display_name) LIKE ? OR lower(coalesce(u.email, '')) LIKE ?
                ORDER BY u.id DESC LIMIT 50
                """, (rs, i) -> new UserRow(rs.getLong("id"), AccountType.valueOf(rs.getString("account_type")),
                rs.getString("display_name"), rs.getString("email"), rs.getBoolean("disabled"),
                rs.getTimestamp("created_at").toInstant(), rs.getLong("groups")), like, like);
    }

    /** Locks the account and ends every session at once (refresh tokens revoked, access tokens refused). */
    @PostMapping("/users/{userId}/disable")
    @Transactional
    public ResponseEntity<Void> disable(@CurrentUser Long me, @PathVariable Long userId) {
        requireAdmin(me);
        if (userId.equals(me)) throw ApiException.badRequest("self", "Không thể tự khóa tài khoản của mình.");
        User u = users.findById(userId).orElseThrow(() -> ApiException.notFound("tài khoản"));
        u.setDisabled(true);
        tokens.revokeAll(userId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/users/{userId}/enable")
    @Transactional
    public ResponseEntity<Void> enable(@CurrentUser Long me, @PathVariable Long userId) {
        requireAdmin(me);
        users.findById(userId).orElseThrow(() -> ApiException.notFound("tài khoản")).setDisabled(false);
        return ResponseEntity.noContent().build();
    }

    private void requireAdmin(Long me) {
        users.findById(me).filter(u -> u.getAccountType() == AccountType.SYSTEM_ADMIN)
                .orElseThrow(() -> ApiException.forbidden("Chỉ quản trị hệ thống mới vào được."));
    }

    private long count(String sql) {
        Long n = jdbc.queryForObject(sql, Long.class);
        return n == null ? 0 : n;
    }
}
