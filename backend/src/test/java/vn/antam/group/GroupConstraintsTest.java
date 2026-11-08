package vn.antam.group;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;

import vn.antam.IntegrationTest;
import vn.antam.user.User;
import vn.antam.user.UserRepository;

/** The database itself refuses two owners in a group and an elder in two groups, even if service code has a bug. */
class GroupConstraintsTest extends IntegrationTest {

    @Autowired
    UserRepository users;
    @Autowired
    FamilyGroupRepository groups;
    @Autowired
    GroupMemberRepository members;

    @Test
    void aGroupCannotHaveTwoActiveOwners() {
        Instant now = Instant.now();
        User a = users.save(User.caregiver("owner-a-" + now.toEpochMilli() + "@t.vn", "x", "A", null, now));
        User b = users.save(User.caregiver("owner-b-" + now.toEpochMilli() + "@t.vn", "x", "B", null, now));
        FamilyGroup g = groups.save(new FamilyGroup("G", a.getId(), now));
        members.saveAndFlush(new GroupMember(g.getId(), a.getId(), GroupRole.OWNER, now));
        assertThatThrownBy(() -> members.saveAndFlush(new GroupMember(g.getId(), b.getId(), GroupRole.OWNER, now)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void anElderCannotBeInTwoGroups() {
        Instant now = Instant.now();
        User owner = users.save(User.caregiver("owner-c-" + now.toEpochMilli() + "@t.vn", "x", "C", null, now));
        User elder = users.save(User.elder("Bà", null, now));
        FamilyGroup g1 = groups.save(new FamilyGroup("G1", owner.getId(), now));
        FamilyGroup g2 = groups.save(new FamilyGroup("G2", owner.getId(), now));
        members.saveAndFlush(new GroupMember(g1.getId(), elder.getId(), GroupRole.ELDER, now));
        assertThatThrownBy(() -> members.saveAndFlush(new GroupMember(g2.getId(), elder.getId(), GroupRole.ELDER, now)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }
}
