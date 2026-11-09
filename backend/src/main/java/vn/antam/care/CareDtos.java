package vn.antam.care;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import vn.antam.medication.DoseLog;

public final class CareDtos {

    private CareDtos() {
    }

    public enum CheckResult { NONE, ISSUE, NO_RESPONSE }

    /**
     * What the elder's phone sends after one alarm: taken or not, for every medicine of that alarm,
     * plus the answer to "any problem?". Sent from an offline queue, so it may arrive late or twice.
     */
    public record DoseReportRequest(
            @NotNull UUID clientEventId,
            @NotNull LocalDate scheduledDate,
            @NotNull @Pattern(regexp = "([01]\\d|2[0-3]):[0-5]\\d") String scheduledTime,
            @NotEmpty @Size(max = 20) List<@NotNull Long> medicationIds,
            @NotNull DoseLog.Status status,
            @NotNull DoseLog.Source source,
            @NotNull CheckResult checkResult,
            /** Required when checkResult is ISSUE. */
            Alert.Kind issue,
            /** When the elder pressed the button (phone clock); defaults to the arrival time. */
            Instant occurredAt) {
    }

    public record DoseReportResult(List<Long> doseLogIds, Long alertId, boolean duplicate) {
    }

    /** "Tôi thấy không khỏe" and similar, pressed on the elder's home screen outside any alarm. */
    public record ElderAlertRequest(@NotNull UUID clientEventId, @NotNull Alert.Kind kind, Instant occurredAt) {
    }

    public record AlertResponse(Long id, Long elderUserId, String elderName, Alert.Kind kind, Long medicationId,
                                String medicationNames, LocalDate scheduledDate, String scheduledTime, Instant createdAt,
                                Instant resolvedAt, Long resolvedBy, String resolvedByName) {
    }

    public record DoseLogResponse(Long id, Long medicationId, String name, String dosage, LocalDate scheduledDate,
                                  String scheduledTime, DoseLog.Status status, DoseLog.Source source, String checkResult,
                                  Instant loggedAt) {
    }

    /** Recent logs the elder's phone merges into its home screen (e.g. after reinstalling). */
    public record RecentDose(Long medicationId, LocalDate scheduledDate, String scheduledTime, DoseLog.Status status) {
    }

    /** A caregiver marks a dose taken for the elder (e.g. gave the pill in person); it stops the elder's alarm. */
    public record MarkRequest(
            @NotNull UUID clientEventId,
            @NotNull LocalDate scheduledDate,
            @NotNull @Pattern(regexp = "([01]\\d|2[0-3]):[0-5]\\d") String scheduledTime,
            @NotEmpty @Size(max = 20) List<@NotNull Long> medicationIds) {
    }

    /** {@code alreadyLogged}: medicines someone had answered before (first answer wins, nothing was changed). */
    public record MarkResult(List<Long> doseLogIds, List<Long> alreadyLogged) {
    }

    /** One medicine at one time on the caregiver's "Hôm nay" timeline. */
    public record DaySlot(String scheduledTime, Long medicationId, String name, String dosage, String description,
                          String imageUrl, vn.antam.schedule.DoseStatus status, Long doseLogId, DoseLog.Source source,
                          String checkResult, Instant loggedAt, String loggedByName, boolean canMark, boolean canUndo) {
    }

    public record DayCounts(int total, int taken, int notTaken, int missed, int due, int upcoming) {
    }

    /** status: DONE, UPCOMING, DUE or MISSED. */
    public record ExerciseSlot(Long exerciseId, String title, String time, Integer durationMin, String note, String status,
                               Instant loggedAt, DoseLog.Source source, String loggedByName) {
    }

    public record DayView(LocalDate date, Long elderUserId, String callName, String phone, List<DaySlot> slots,
                          DayCounts counts, int missedLast7Days, int openAlerts, List<ExerciseSlot> exercises) {
    }

    /** One cell of the caregiver's week / month calendar. */
    public record CalendarDay(LocalDate date, int total, int taken, int notTaken, int missed, int due, int upcoming,
                              int exercises, int exercisesDone, int exercisesMissed) {
    }
}
