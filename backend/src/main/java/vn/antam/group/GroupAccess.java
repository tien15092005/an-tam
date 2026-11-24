package vn.antam.group;

import org.springframework.stereotype.Component;

import vn.antam.common.ApiException;

/**
 * Object-level authorization for family groups. Every group endpoint goes through here.
 * Non-members get 404 (not 403) so they cannot probe which group ids exist.
 */
@Component
public class GroupAccess {

    private final GroupMemberRepository members;
    private final FamilyGroupRepository groups;

    public GroupAccess(GroupMemberRepository members, FamilyGroupRepository groups) {
        this.members = members;
        this.groups = groups;
    }

    public GroupMember requireMember(Long groupId, Long userId) {
        FamilyGroup group = groups.findById(groupId).filter(g -> !g.isDeleted())
                .orElseThrow(() -> ApiException.notFound("nhóm"));
        return members.findByGroupIdAndUserIdAndLeftAtIsNull(group.getId(), userId)
                .orElseThrow(() -> ApiException.notFound("nhóm"));
    }

    /** Caregivers only (owner or member); elders cannot see e.g. other members' contact details. */
    public GroupMember requireCaregiver(Long groupId, Long userId) {
        GroupMember m = requireMember(groupId, userId);
        if (m.getRole() == GroupRole.ELDER) throw ApiException.forbidden("Chức năng này dành cho người con.");
        return m;
    }

    public GroupMember requireOwner(Long groupId, Long userId) {
        GroupMember m = requireMember(groupId, userId);
        if (m.getRole() != GroupRole.OWNER) throw ApiException.forbidden("Chỉ trưởng nhóm mới được làm việc này.");
        return m;
    }
}
