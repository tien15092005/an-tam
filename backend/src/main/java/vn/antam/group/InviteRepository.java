package vn.antam.group;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface InviteRepository extends JpaRepository<Invite, Long> {

    /** Serialises pairing-code creation until the transaction ends (check-then-insert stays atomic). */
    @org.springframework.data.jpa.repository.Query(value = "SELECT 1 FROM (SELECT pg_advisory_xact_lock(47110001)) AS l",
            nativeQuery = true)
    Integer lockCodeCreation();

    Optional<Invite> findFirstByKindAndCodeHashAndUsedAtIsNullAndExpiresAtAfter(Invite.Kind kind, String codeHash, Instant now);

    boolean existsByCodeHashAndUsedAtIsNullAndExpiresAtAfter(String codeHash, Instant now);

    List<Invite> findByKindAndElderUserIdAndUsedAtIsNullAndExpiresAtAfter(Invite.Kind kind, Long elderUserId, Instant now);
}
