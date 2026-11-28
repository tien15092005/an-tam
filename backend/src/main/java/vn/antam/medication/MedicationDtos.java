package vn.antam.medication;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Request and response bodies for the medication API. */
public final class MedicationDtos {

    private MedicationDtos() {
    }

    public record MedicationRequest(
            @NotBlank @Size(max = 120) String name,
            @Size(max = 60) String strength,
            @Size(max = 60) String dosage,
            @Size(max = 300) String note,
            @Size(max = 40) String shape,
            @Size(max = 40) String color,
            @Size(max = 40) String imprint,
            @Size(max = 300) String pillDescription,
            @NotEmpty @Size(max = 8) List<@Pattern(regexp = "([01]\\d|2[0-3]):[0-5]\\d") String> times,
            /** ISO weekdays 1 (Mon) … 7 (Sun); empty or missing means every day. */
            List<Integer> daysOfWeek,
            /** Defaults to today in the elder's time zone. */
            LocalDate startDate,
            /** Null = taken until further notice. */
            LocalDate endDate,
            Medication.Source source) {
    }

    public record ImageInfo(Long id, MedicationImage.Kind kind, String url, String sha256) {
    }

    public record MedicationResponse(
            Long id, UUID seriesId, Long elderUserId, String name, String strength, String dosage, String note,
            String shape, String color, String imprint, String pillDescription, List<String> times,
            List<Integer> daysOfWeek, LocalDate startDate, LocalDate endDate, Medication.Source source,
            List<ImageInfo> images, Instant createdAt, Instant updatedAt) {
    }

    /** What the elder's phone downloads to arm its alarms; scheduleVersion changes on every edit. */
    public record ScheduleResponse(Long groupId, Long elderUserId, String callName, String timezone,
                                   long scheduleVersion, List<MedicationResponse> medications,
                                   List<vn.antam.care.CareDtos.RecentDose> recentDoses,
                                   List<vn.antam.exercise.ExerciseDtos.ExerciseResponse> exercises,
                                   List<vn.antam.exercise.ExerciseDtos.RecentExercise> recentExercises,
                                   /** The parent's UTC offset right now, so the phone can warn when its own clock zone differs. */
                                   int utcOffsetMinutes) {
    }
}
