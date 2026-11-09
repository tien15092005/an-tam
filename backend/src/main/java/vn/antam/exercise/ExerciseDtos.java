package vn.antam.exercise;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import vn.antam.medication.DoseLog;

public final class ExerciseDtos {

    private ExerciseDtos() {
    }

    /** @param daysOfWeek ISO days, 1 = Monday ... 7 = Sunday; empty or null = every day */
    public record ExerciseRequest(
            @NotBlank @Size(max = 120) String title,
            @NotNull @Pattern(regexp = "([01]\\d|2[0-3]):[0-5]\\d") String time,
            @Size(max = 7) List<@Min(1) @Max(7) Integer> daysOfWeek,
            @Min(1) @Max(240) Integer durationMin,
            @Size(max = 300) String note,
            LocalDate startDate,
            LocalDate endDate) {
    }

    public record ExerciseResponse(Long id, UUID seriesId, Long elderUserId, String title, String time,
                                   List<Integer> daysOfWeek, Integer durationMin, String note, LocalDate startDate,
                                   LocalDate endDate, Instant createdAt) {
    }

    /** "TÔI ĐI TẬP ĐÂY" from the elder's phone (offline queue: may arrive late or twice). */
    public record ExerciseReportRequest(@NotNull UUID clientEventId, @NotNull Long exerciseId,
                                        @NotNull LocalDate scheduledDate, @NotNull DoseLog.Source source) {
    }

    public record ExerciseReportResult(Long exerciseLogId, boolean duplicate) {
    }

    /** Recent "done" marks sent with the elder's schedule. */
    public record RecentExercise(Long exerciseId, LocalDate scheduledDate) {
    }
}
