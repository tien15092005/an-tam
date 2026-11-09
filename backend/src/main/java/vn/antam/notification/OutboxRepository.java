package vn.antam.notification;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

public interface OutboxRepository extends JpaRepository<OutboxEntry, Long> {

    boolean existsByDedupeKey(String dedupeKey);

    List<OutboxEntry> findTop50ByStatusOrderByCreatedAt(OutboxEntry.Status status);

    List<OutboxEntry> findByUserIdOrderById(Long userId);
}
