package vn.antam.exercise;

import java.time.LocalDate;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ExerciseRepository extends JpaRepository<Exercise, Long> {

    @Query("""
            select e from Exercise e
            where e.elderUserId = :elder and e.active = true and (e.endDate is null or e.endDate >= :today)
            order by e.timeOfDay, e.title
            """)
    List<Exercise> current(@Param("elder") Long elderUserId, @Param("today") LocalDate today);

    @Query("""
            select e from Exercise e
            where e.elderUserId = :elder and e.active = true
              and e.startDate <= :to and (e.endDate is null or e.endDate >= :from)
            order by e.timeOfDay, e.title
            """)
    List<Exercise> overlapping(@Param("elder") Long elderUserId, @Param("from") LocalDate from, @Param("to") LocalDate to);
}
