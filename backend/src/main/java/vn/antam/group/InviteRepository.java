package vn.antam.group;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface InviteRepository extends JpaRepository<Invite, Long> {

    Optional<Invite> findFirstByKindAndCodeHashAndUsedAtIsNullAndExpiresAtAfter(Invite.Kind kind, String codeHash, Instant now);

    boolean existsByCodeHashAndUsedAtIsNullAndExpiresAtAfter(String codeHash, Instant now);

    List<Invite> findByKindAndElderUserIdAndUsedAtIsNullAndExpiresAtAfter(Invite.Kind kind, Long elderUserId, Instant now);
}
