package vn.antam.medication;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

public interface MedicationImageRepository extends JpaRepository<MedicationImage, Long> {

    List<MedicationImage> findByMedicationIdAndDeletedAtIsNullOrderBySortOrder(Long medicationId);

    List<MedicationImage> findByMedicationIdInAndDeletedAtIsNullOrderBySortOrder(List<Long> medicationIds);
}
