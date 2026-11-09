package vn.antam.medication;

import java.time.LocalDate;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MedicationRepository extends JpaRepository<Medication, Long> {

    /** Versions that are active and not finished before {@code today}: what the elder still takes. */
    @Query("""
            select m from Medication m
            where m.elderUserId = :elder and m.active = true
              and (m.endDate is null or m.endDate >= :today)
            order by m.name
            """)
    List<Medication> current(@Param("elder") Long elderUserId, @Param("today") LocalDate today);

    /** Active versions whose date range touches from..to (a closed old version and its successor both count). */
    @Query("""
            select m from Medication m
            where m.elderUserId = :elder and m.active = true
              and m.startDate <= :to and (m.endDate is null or m.endDate >= :from)
            order by m.name
            """)
    List<Medication> overlapping(@Param("elder") Long elderUserId, @Param("from") LocalDate from, @Param("to") LocalDate to);
}
