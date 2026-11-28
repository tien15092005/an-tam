package vn.antam.notification;

import java.time.Instant;
import java.util.List;

import org.springframework.data.domain.Limit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface OutboxRepository extends JpaRepository<OutboxEntry, Long> {

    boolean existsByDedupeKey(String dedupeKey);

    /** Pending entries whose retry time has come, oldest first. */
    @Query("select e from OutboxEntry e where e.status = vn.antam.notification.OutboxEntry.Status.PENDING "
            + "and (e.nextAttemptAt is null or e.nextAttemptAt <= :now) order by e.createdAt")
    List<OutboxEntry> findDue(@Param("now") Instant now, Limit limit);

    List<OutboxEntry> findByUserIdOrderById(Long userId);
}
