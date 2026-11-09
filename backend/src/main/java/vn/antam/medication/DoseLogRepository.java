package vn.antam.medication;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface DoseLogRepository extends JpaRepository<DoseLog, Long> {

    boolean existsByMedicationId(Long medicationId);

    Optional<DoseLog> findByMedicationIdAndScheduledDateAndScheduledTime(Long medicationId, LocalDate date, LocalTime time);

    Optional<DoseLog> findByClientEventId(UUID clientEventId);

    List<DoseLog> findByElderUserIdAndScheduledDateBetweenOrderByScheduledDateAscScheduledTimeAsc(
            Long elderUserId, LocalDate from, LocalDate to);

    List<DoseLog> findByElderUserIdInAndScheduledDateOrderByScheduledTimeAsc(Collection<Long> elderUserIds, LocalDate date);
}
