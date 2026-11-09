package vn.antam.care;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface AlertRepository extends JpaRepository<Alert, Long> {

    Optional<Alert> findByClientEventId(UUID clientEventId);

    List<Alert> findTop100ByGroupIdOrderByCreatedAtDesc(Long groupId);

    List<Alert> findByGroupIdAndResolvedAtIsNullOrderByCreatedAtDesc(Long groupId);

    long countByGroupIdAndElderUserIdAndResolvedAtIsNull(Long groupId, Long elderUserId);

    Optional<Alert> findByElderUserIdAndKindAndScheduledDateAndScheduledTimeAndResolvedAtIsNull(
            Long elderUserId, Alert.Kind kind, java.time.LocalDate date, java.time.LocalTime time);

    /** Before a caregiver's mark is undone: an elder's later report may point its alert at that log. */
    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.data.jpa.repository.Query("update Alert a set a.doseLogId = null where a.doseLogId = :id")
    void detachDoseLog(@org.springframework.data.repository.query.Param("id") Long doseLogId);
}
