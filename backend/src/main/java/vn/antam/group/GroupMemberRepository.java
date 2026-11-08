package vn.antam.group;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface GroupMemberRepository extends JpaRepository<GroupMember, Long> {

    Optional<GroupMember> findByGroupIdAndUserIdAndLeftAtIsNull(Long groupId, Long userId);

    List<GroupMember> findByGroupIdAndLeftAtIsNullOrderByJoinedAt(Long groupId);

    List<GroupMember> findByUserIdAndLeftAtIsNull(Long userId);

    Optional<GroupMember> findByGroupIdAndRoleAndLeftAtIsNull(Long groupId, GroupRole role);

    long countByGroupIdAndRoleInAndLeftAtIsNull(Long groupId, List<GroupRole> roles);
}
