package vn.antam.user;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;

import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import vn.antam.auth.CurrentUser;
import vn.antam.auth.TokenService;
import vn.antam.common.ApiException;
import vn.antam.group.GroupMember;
import vn.antam.group.GroupMemberRepository;
import vn.antam.group.GroupRole;
import vn.antam.group.GroupService;

/**
 * "Xóa tài khoản và dữ liệu" (plan §11). A caregiver leaves every group (an owner must hand over first when
 * others remain; as the last caregiver the group is deleted, and with it the elders' personal data and photos),
 * and the account keeps only an anonymous row so history stays consistent.
 */
@RestController
@RequestMapping("/api/me")
public class AccountController {

    private final UserRepository users;
    private final GroupMemberRepository members;
    private final GroupService groups;
    private final TokenService tokens;
    private final JdbcTemplate jdbc;
    private final Clock clock;

    public AccountController(UserRepository users, GroupMemberRepository members, GroupService groups, TokenService tokens,
                             JdbcTemplate jdbc, Clock clock) {
        this.users = users;
        this.members = members;
        this.groups = groups;
        this.tokens = tokens;
        this.jdbc = jdbc;
        this.clock = clock;
    }

    @DeleteMapping
    @Transactional
    public ResponseEntity<Void> deleteMe(@CurrentUser Long me, @RequestParam(defaultValue = "false") boolean confirm) {
        User user = users.findById(me).orElseThrow(() -> ApiException.notFound("tài khoản"));
        if (user.getAccountType() != AccountType.CAREGIVER) {
            throw ApiException.forbidden("Tài khoản của bố mẹ do trưởng nhóm quản lý.");
        }
        if (!confirm) throw ApiException.conflict("confirm_required", "Xác nhận để xóa tài khoản và dữ liệu.");
        for (GroupMember m : members.findByUserIdAndLeftAtIsNull(me)) {
            Long groupId = m.getGroupId();
            // Throws transfer_required for an owner with other caregivers; the last child erases the family.
            groups.leave(me, groupId, true);
        }
        jdbc.update("DELETE FROM devices WHERE user_id = ?", me);
        jdbc.update("DELETE FROM notification_outbox WHERE user_id = ?", me);
        tokens.revokeAll(me);
        user.anonymize();
        return ResponseEntity.noContent().build();
    }
}
