package vn.antam.care;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface AlertRepository extends JpaRepository<Alert, Long> {

    Optional<Alert> findByClientEventId(UUID clientEventId);

    List<Alert> findTop100ByGroupIdOrderByCreatedAtDesc(Long groupId);

    List<Alert> findByGroupIdAndResolvedAtIsNullOrderByCreatedAtDesc(Long groupId);
}
