package vn.antam.group;

import org.springframework.data.jpa.repository.JpaRepository;

public interface ElderProfileRepository extends JpaRepository<ElderProfile, Long> {

    /** Parents still in their family (not removed, family not deleted): the ones whose doses are watched. */
    @org.springframework.data.jpa.repository.Query(value = """
            SELECT p.* FROM elder_profiles p
            JOIN group_members m ON m.group_id = p.group_id AND m.user_id = p.user_id
                                AND m.role = 'ELDER' AND m.left_at IS NULL
            JOIN family_groups g ON g.id = p.group_id AND g.deleted_at IS NULL
            """, nativeQuery = true)
    java.util.List<ElderProfile> findActive();
}
