package vn.antam.medication;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

/** Validated editable fields of a medication, independent of the HTTP request shape. */
public record MedicationFields(
        String name,
        String strength,
        String dosage,
        String note,
        String shape,
        String color,
        String imprint,
        String pillDescription,
        List<LocalTime> times,
        short daysOfWeekMask,
        LocalDate startDate,
        LocalDate endDate,
        Medication.Source source) {

    /** True when the change affects what or when the elder takes (worth a new version once history exists). */
    boolean changesScheduleOf(Medication m) {
        return !equalsNullable(name, m.getName())
                || !equalsNullable(strength, m.getStrength())
                || !equalsNullable(dosage, m.getDosage())
                || daysOfWeekMask != m.getDaysOfWeek()
                || !times.equals(m.timeList());
    }

    private static boolean equalsNullable(String a, String b) {
        return a == null ? b == null : a.equals(b);
    }
}
