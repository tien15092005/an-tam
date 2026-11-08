package vn.antam.group;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import vn.antam.auth.AttemptLimiter;
import vn.antam.auth.Secrets;
import vn.antam.auth.TokenService;
import vn.antam.common.ApiException;
import vn.antam.group.GroupDtos.CodeResponse;
import vn.antam.group.GroupDtos.ElderInfo;
import vn.antam.group.GroupDtos.ElderRequest;
import vn.antam.group.GroupDtos.GroupDetail;
import vn.antam.group.GroupDtos.GroupSummary;
import vn.antam.group.GroupDtos.Member;
import vn.antam.user.AccountType;
import vn.antam.user.User;
import vn.antam.user.UserRepository;

/** Family groups: one owner who sets schedules, other caregivers, and the elders they look after. */
@Service
public class GroupService {

    static final Duration PAIRING_CODE_TTL = Duration.ofMinutes(15);
    static final Duration MEMBER_INVITE_TTL = Duration.ofDays(7);
    private static final List<GroupRole> CAREGIVER_ROLES = List.of(GroupRole.OWNER, GroupRole.MEMBER);

    private final FamilyGroupRepository groups;
    private final GroupMemberRepository members;
    private final ElderProfileRepository elders;
    private final InviteRepository invites;
    private final UserRepository users;
    private final GroupAccess access;
    private final Secrets secrets;
    private final TokenService tokens;
    private final AttemptLimiter limiter;
    private final Clock clock;

    public GroupService(FamilyGroupRepository groups, GroupMemberRepository members, ElderProfileRepository elders,
                        InviteRepository invites, UserRepository users, GroupAccess access, Secrets secrets,
                        TokenService tokens, AttemptLimiter limiter, Clock clock) {
        this.groups = groups;
        this.members = members;
        this.elders = elders;
        this.invites = invites;
        this.users = users;
        this.access = access;
        this.secrets = secrets;
        this.tokens = tokens;
        this.limiter = limiter;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<GroupSummary> myGroups(Long userId) {
        return members.findByUserIdAndLeftAtIsNull(userId).stream()
                .map(m -> groups.findById(m.getGroupId())
                        .filter(g -> !g.isDeleted())
                        .map(g -> new GroupSummary(g.getId(), g.getName(), m.getRole()))
                        .orElse(null))
                .filter(java.util.Objects::nonNull)
                .toList();
    }

    @Transactional
    public GroupSummary create(Long userId, String name) {
        requireCaregiverAccount(userId);
        Instant now = clock.instant();
        FamilyGroup group = groups.save(new FamilyGroup(name.trim(), userId, now));
        members.save(new GroupMember(group.getId(), userId, GroupRole.OWNER, now));
        return new GroupSummary(group.getId(), group.getName(), GroupRole.OWNER);
    }

    @Transactional(readOnly = true)
    public GroupDetail detail(Long userId, Long groupId) {
        GroupMember me = access.requireMember(groupId, userId);
        FamilyGroup group = groups.findById(groupId).orElseThrow();
        List<GroupMember> active = members.findByGroupIdAndLeftAtIsNullOrderByJoinedAt(groupId);
        Map<Long, User> byId = users.findAllById(active.stream().map(GroupMember::getUserId).toList()).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        List<Member> list = active.stream().map(m -> {
            User u = byId.get(m.getUserId());
            ElderInfo elder = m.getRole() == GroupRole.ELDER
                    ? elders.findById(m.getUserId())
                        .map(p -> new ElderInfo(p.getCallName(), p.getBirthYear(), p.getHealthNote(), p.getTimezone()))
                        .orElse(null)
                    : null;
            // Phones are visible to the elder too: the elder's home screen has a "call my child" button.
            return new Member(u.getId(), u.getDisplayName(), u.getPhone(), m.getRole(), m.getJoinedAt(), elder);
        }).toList();
        return new GroupDetail(group.getId(), group.getName(), me.getRole(), group.getScheduleVersion(), list);
    }

    @Transactional
    public void rename(Long userId, Long groupId, String name) {
        access.requireOwner(groupId, userId);
        groups.findById(groupId).orElseThrow().rename(name.trim());
    }

    @Transactional
    public CodeResponse createMemberInvite(Long userId, Long groupId) {
        access.requireOwner(groupId, userId);
        Instant now = clock.instant();
        String code = secrets.inviteCode();
        Invite invite = invites.save(new Invite(Invite.Kind.MEMBER, secrets.hashCode(code), groupId, null, userId,
                now, now.plus(MEMBER_INVITE_TTL)));
        return new CodeResponse(code, invite.getExpiresAt());
    }

    @Transactional
    public GroupSummary acceptInvite(Long userId, String code, String ip) {
        requireCaregiverAccount(userId);
        limiter.check("invite:ip:" + ip, 20, Duration.ofMinutes(10));
        Instant now = clock.instant();
        Invite invite = invites.findFirstByKindAndCodeHashAndUsedAtIsNullAndExpiresAtAfter(
                        Invite.Kind.MEMBER, secrets.hashCode(code), now)
                .orElseThrow(() -> ApiException.badRequest("invalid_code", "Mã mời không đúng hoặc đã hết hạn."));
        FamilyGroup group = groups.findById(invite.getGroupId()).filter(g -> !g.isDeleted())
                .orElseThrow(() -> ApiException.badRequest("invalid_code", "Mã mời không đúng hoặc đã hết hạn."));
        if (members.findByGroupIdAndUserIdAndLeftAtIsNull(group.getId(), userId).isPresent()) {
            throw ApiException.conflict("already_member", "Bạn đã ở trong nhóm này rồi.");
        }
        invite.markUsed(userId, now);
        members.save(new GroupMember(group.getId(), userId, GroupRole.MEMBER, now));
        return new GroupSummary(group.getId(), group.getName(), GroupRole.MEMBER);
    }

    @Transactional
    public Member addElder(Long userId, Long groupId, ElderRequest r) {
        access.requireOwner(groupId, userId);
        Instant now = clock.instant();
        User elder = users.save(User.elder(r.callName().trim(), blankToNull(r.phone()), now));
        ElderProfile profile = new ElderProfile(elder.getId(), groupId);
        profile.update(r.callName().trim(), r.birthYear(), blankToNull(r.phone()), blankToNull(r.healthNote()), r.timezone());
        elders.save(profile);
        GroupMember m = members.save(new GroupMember(groupId, elder.getId(), GroupRole.ELDER, now));
        return new Member(elder.getId(), elder.getDisplayName(), elder.getPhone(), GroupRole.ELDER, m.getJoinedAt(),
                new ElderInfo(profile.getCallName(), profile.getBirthYear(), profile.getHealthNote(), profile.getTimezone()));
    }

    @Transactional
    public void updateElder(Long userId, Long groupId, Long elderUserId, ElderRequest r) {
        access.requireOwner(groupId, userId);
        ElderProfile profile = elderInGroup(groupId, elderUserId);
        profile.update(r.callName().trim(), r.birthYear(), blankToNull(r.phone()), blankToNull(r.healthNote()), r.timezone());
        users.findById(elderUserId).orElseThrow().rename(r.callName().trim(), blankToNull(r.phone()));
    }

    /** New 6-digit code for the elder's phone. Earlier unused codes for that elder stop working. */
    @Transactional
    public CodeResponse createPairingCode(Long userId, Long groupId, Long elderUserId) {
        access.requireOwner(groupId, userId);
        elderInGroup(groupId, elderUserId);
        Instant now = clock.instant();
        invites.findByKindAndElderUserIdAndUsedAtIsNullAndExpiresAtAfter(Invite.Kind.ELDER_DEVICE, elderUserId, now)
                .forEach(i -> i.expire(now));
        String code;
        String hash;
        do {
            code = secrets.sixDigitCode();
            hash = secrets.hashCode(code);
        } while (invites.existsByCodeHashAndUsedAtIsNullAndExpiresAtAfter(hash, now));
        Invite invite = invites.save(new Invite(Invite.Kind.ELDER_DEVICE, hash, groupId, elderUserId, userId,
                now, now.plus(PAIRING_CODE_TTL)));
        return new CodeResponse(code, invite.getExpiresAt());
    }

    @Transactional
    public void transferOwnership(Long userId, Long groupId, Long targetUserId) {
        GroupMember owner = access.requireOwner(groupId, userId);
        GroupMember target = members.findByGroupIdAndUserIdAndLeftAtIsNull(groupId, targetUserId)
                .filter(m -> m.getRole() == GroupRole.MEMBER)
                .orElseThrow(() -> ApiException.badRequest("invalid_target", "Chỉ chuyển quyền được cho một người con khác trong nhóm."));
        // Demote first and flush: the database allows only one active owner at a time.
        owner.changeRole(GroupRole.MEMBER);
        members.saveAndFlush(owner);
        target.changeRole(GroupRole.OWNER);
    }

    @Transactional
    public void removeMember(Long userId, Long groupId, Long targetUserId) {
        access.requireOwner(groupId, userId);
        if (userId.equals(targetUserId)) {
            throw ApiException.badRequest("cannot_remove_self", "Trưởng nhóm muốn rời nhóm thì dùng chức năng Rời nhóm.");
        }
        GroupMember target = members.findByGroupIdAndUserIdAndLeftAtIsNull(groupId, targetUserId)
                .orElseThrow(() -> ApiException.notFound("thành viên"));
        if (target.getRole() != GroupRole.MEMBER) {
            throw ApiException.badRequest("cannot_remove", "Chỉ xóa được người con khỏi nhóm.");
        }
        target.leave(clock.instant());
    }

    /**
     * Leaves a group. The owner must hand over first; if nobody else can take over,
     * leaving deletes the group, which requires an explicit confirmation.
     */
    @Transactional
    public void leave(Long userId, Long groupId, boolean confirmDelete) {
        GroupMember me = access.requireMember(groupId, userId);
        Instant now = clock.instant();
        switch (me.getRole()) {
            case ELDER -> throw ApiException.forbidden("Người già không tự rời nhóm. Nhờ trưởng nhóm xử lý.");
            case MEMBER -> me.leave(now);
            case OWNER -> {
                long caregivers = members.countByGroupIdAndRoleInAndLeftAtIsNull(groupId, CAREGIVER_ROLES);
                if (caregivers > 1) {
                    throw ApiException.conflict("transfer_required", "Hãy chuyển quyền trưởng nhóm cho người khác trước khi rời nhóm.");
                }
                if (!confirmDelete) {
                    throw ApiException.conflict("confirm_delete_required", "Bạn là người con duy nhất. Rời nhóm sẽ xóa nhóm này.");
                }
                deleteGroup(groupId, now);
            }
        }
    }

    private void deleteGroup(Long groupId, Instant now) {
        for (GroupMember m : members.findByGroupIdAndLeftAtIsNullOrderByJoinedAt(groupId)) {
            m.leave(now);
            if (m.getRole() == GroupRole.ELDER) tokens.revokeAll(m.getUserId());
        }
        groups.findById(groupId).orElseThrow().delete(now);
    }

    private ElderProfile elderInGroup(Long groupId, Long elderUserId) {
        return members.findByGroupIdAndUserIdAndLeftAtIsNull(groupId, elderUserId)
                .filter(m -> m.getRole() == GroupRole.ELDER)
                .flatMap(m -> elders.findById(elderUserId))
                .orElseThrow(() -> ApiException.notFound("người già trong nhóm"));
    }

    private void requireCaregiverAccount(Long userId) {
        User u = users.findById(userId).orElseThrow(() -> ApiException.notFound("tài khoản"));
        if (u.getAccountType() != AccountType.CAREGIVER) {
            throw ApiException.forbidden("Chức năng này dành cho tài khoản người con.");
        }
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
