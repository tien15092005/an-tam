package vn.antam.exercise;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface ExerciseLogRepository extends JpaRepository<ExerciseLog, Long> {

    Optional<ExerciseLog> findByClientEventId(UUID clientEventId);

    Optional<ExerciseLog> findByExerciseIdAndScheduledDate(Long exerciseId, LocalDate date);

    boolean existsByExerciseId(Long exerciseId);

    List<ExerciseLog> findByElderUserIdAndScheduledDateBetweenOrderByScheduledDate(Long elderUserId, LocalDate from,
                                                                                 LocalDate to);
}
