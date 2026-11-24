package vn.antam.care;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import vn.antam.care.CareDtos.AlertResponse;
import vn.antam.care.CareDtos.CheckResult;
import vn.antam.care.CareDtos.DoseLogResponse;
import vn.antam.care.CareDtos.DoseReportRequest;
import vn.antam.care.CareDtos.DoseReportResult;
import vn.antam.care.CareDtos.ElderAlertRequest;
import vn.antam.care.CareDtos.RecentDose;
import vn.antam.common.ApiException;
import vn.antam.group.ElderProfile;
import vn.antam.group.ElderProfileRepository;
import vn.antam.group.GroupAccess;
import vn.antam.group.GroupMemberRepository;
import vn.antam.group.GroupRole;
import vn.antam.medication.DoseLog;
import vn.antam.medication.DoseLogRepository;
import vn.antam.medication.Medication;
import vn.antam.medication.MedicationRepository;
import vn.antam.notification.Notifier;
import vn.antam.user.User;
import vn.antam.user.UserRepository;

/**
 * The elder's side of an alarm (taken / not taken, "any problem?") and the alerts it raises for
 * caregivers (plan §9). Every write is idempotent on the phone's clientEventId, because the phone
 * resends from an offline queue until it gets an answer.
 */
@Service
public class CareService {

    private final DoseLogRepository doseLogs;
    private final AlertRepository alerts;
    private final MedicationRepository medications;
    private final ElderProfileRepository elders;
    private final GroupMemberRepository members;
    private final GroupAccess access;
    private final UserRepository users;
    private final Notifier notifier;
    private final TodayService today;
    private final Clock clock;

    public CareService(DoseLogRepository doseLogs, AlertRepository alerts, MedicationRepository medications,
                       ElderProfileRepository elders, GroupMemberRepository members, GroupAccess access,
                       UserRepository users, Notifier notifier, TodayService today, Clock clock) {
        this.doseLogs = doseLogs;
        this.alerts = alerts;
        this.medications = medications;
        this.elders = elders;
        this.members = members;
        this.access = access;
        this.users = users;
        this.notifier = notifier;
        this.today = today;
        this.clock = clock;
    }

    /** Dose log ids are derived from the report id, so a resent report finds its own rows again. */
    static UUID doseEventId(UUID reportId, Long medicationId) {
        return UUID.nameUUIDFromBytes((reportId + ":" + medicationId).getBytes(StandardCharsets.UTF_8));
    }

    @Transactional
    public DoseReportResult report(Long elderUserId, DoseReportRequest r) {
        ElderProfile elder = activeElder(elderUserId);
        if (r.status() == DoseLog.Status.SKIPPED || r.source() == DoseLog.Source.CAREGIVER) {
            throw ApiException.badRequest("validation", "Máy người già chỉ báo đã uống hoặc không uống được.");
        }
        Alert.Kind issue = issueOf(r.checkResult(), r.issue());
        LocalTime time = LocalTime.parse(r.scheduledTime());
        Instant now = clock.instant();
        Instant at = r.occurredAt() == null || r.occurredAt().isAfter(now) ? now : r.occurredAt();

        // Already received (the phone did not get our answer last time): return what we stored.
        Optional<Alert> sameAlert = alerts.findByClientEventId(r.clientEventId());
        List<Long> existing = new ArrayList<>();
        for (Long medId : r.medicationIds()) {
            doseLogs.findByClientEventId(doseEventId(r.clientEventId(), medId)).ifPresent(d -> existing.add(d.getId()));
        }
        if (!existing.isEmpty() || sameAlert.isPresent()) {
            return new DoseReportResult(existing, sameAlert.map(Alert::getId).orElse(null), true);
        }

        List<DoseLog> logs = new ArrayList<>();
        List<String> names = new ArrayList<>();
        boolean[] createdAny = {false};
        for (Long medId : r.medicationIds().stream().distinct().toList()) {
            Medication m = medications.findById(medId)
                    .filter(x -> x.getElderUserId().equals(elderUserId) && x.getGroupId().equals(elder.getGroupId()))
                    .orElseThrow(() -> ApiException.notFound("thuốc"));
            names.add(m.getName());
            // First answer for a dose wins (e.g. a caregiver already marked it, or another report got there first).
            DoseLog log = doseLogs.findByMedicationIdAndScheduledDateAndScheduledTime(medId, r.scheduledDate(), time)
                    .orElseGet(() -> {
                        DoseLog d = new DoseLog(m, r.scheduledDate(), time, r.status(), r.source(),
                                doseEventId(r.clientEventId(), medId), elderUserId, at);
                        d.setCheckResult(r.checkResult().name());
                        createdAny[0] = true;
                        return doseLogs.save(d);
                    });
            logs.add(log);
        }

        // Answered after the caregivers were told "chưa xác nhận": settle that alert and say it came late.
        boolean late = today.resolveNotConfirmedIfAnswered(elderUserId, r.scheduledDate(), time, elderUserId, now);
        Long alertId = null;
        if (issue != null) {
            Alert a = new Alert(elder.getGroupId(), elderUserId, issue, r.clientEventId(), now);
            a.aboutDose(logs.getFirst().getId(), logs.size() == 1 ? logs.getFirst().getMedicationId() : null,
                    String.join(", ", names), r.scheduledDate(), time);
            alertId = alerts.save(a).getId();
            notifyAlert(a, elder);
        } else if (createdAny[0]) {
            // One notification per report and person: an alert replaces the plain report.
            notifier.toCaregivers(elder.getGroupId(), Notifier.Kind.DOSE_REPORT, logs.getFirst().getId(),
                    "report:" + r.clientEventId(), CareTexts.reportTitle(elder.getCallName(), r.status()),
                    r.scheduledTime() + " · " + String.join(", ", names) + (late ? " · trả lời muộn" : ""),
                    r.status() != DoseLog.Status.TAKEN, null);
        }
        return new DoseReportResult(logs.stream().map(DoseLog::getId).toList(), alertId, false);
    }

    @Transactional
    public AlertResponse elderAlert(Long elderUserId, ElderAlertRequest r) {
        ElderProfile elder = activeElder(elderUserId);
        if (r.kind() == Alert.Kind.NOT_CONFIRMED) {
            throw ApiException.badRequest("validation", "Loại cảnh báo này do hệ thống tạo.");
        }
        Optional<Alert> existing = alerts.findByClientEventId(r.clientEventId());
        if (existing.isPresent()) return toResponses(List.of(existing.get())).getFirst();
        Alert a = alerts.save(new Alert(elder.getGroupId(), elderUserId, r.kind(), r.clientEventId(), clock.instant()));
        notifyAlert(a, elder);
        return toResponses(List.of(a)).getFirst();
    }

    @Transactional(readOnly = true)
    public List<AlertResponse> alerts(Long userId, Long groupId, boolean openOnly) {
        access.requireCaregiver(groupId, userId);
        return toResponses(openOnly ? alerts.findByGroupIdAndResolvedAtIsNullOrderByCreatedAtDesc(groupId)
                : alerts.findTop100ByGroupIdOrderByCreatedAtDesc(groupId));
    }

    /** Any caregiver may resolve; resolving twice keeps the first resolver, so others see who handled it. */
    @Transactional
    public AlertResponse resolve(Long userId, Long groupId, Long alertId) {
        access.requireCaregiver(groupId, userId);
        Alert a = alerts.findById(alertId).filter(x -> x.getGroupId().equals(groupId))
                .orElseThrow(() -> ApiException.notFound("cảnh báo"));
        a.resolve(userId, clock.instant());
        return toResponses(List.of(a)).getFirst();
    }

    /** One day of an elder's dose logs, for caregivers. */
    @Transactional(readOnly = true)
    public List<DoseLogResponse> dosesOn(Long userId, Long groupId, Long elderUserId, LocalDate date) {
        access.requireCaregiver(groupId, userId);
        members.findByGroupIdAndUserIdAndLeftAtIsNull(groupId, elderUserId).filter(m -> m.getRole() == GroupRole.ELDER)
                .orElseThrow(() -> ApiException.notFound("người già trong nhóm"));
        return doseLogs.findByElderUserIdAndScheduledDateBetweenOrderByScheduledDateAscScheduledTimeAsc(elderUserId, date, date)
                .stream()
                .map(d -> new DoseLogResponse(d.getId(), d.getMedicationId(), d.getNameSnapshot(), d.getDosageSnapshot(),
                        d.getScheduledDate(), hhmm(d.getScheduledTime()), d.getStatus(), d.getSource(), d.getCheckResult(),
                        d.getLoggedAt()))
                .toList();
    }

    /** Yesterday's and today's logs, sent with the elder's schedule. */
    @Transactional(readOnly = true)
    public List<RecentDose> recentFor(ElderProfile elder) {
        LocalDate today = LocalDate.now(clock.withZone(ZoneId.of(elder.getTimezone())));
        return doseLogs.findByElderUserIdAndScheduledDateBetweenOrderByScheduledDateAscScheduledTimeAsc(
                        elder.getUserId(), today.minusDays(1), today)
                .stream().map(d -> new RecentDose(d.getMedicationId(), d.getScheduledDate(), hhmm(d.getScheduledTime()), d.getStatus()))
                .toList();
    }

    // ---- helpers

    private void notifyAlert(Alert a, ElderProfile elder) {
        notifier.toCaregivers(a.getGroupId(), Notifier.Kind.ALERT, a.getId(), "alert:" + a.getId(),
                CareTexts.alertTitle(elder.getCallName(), a.getKind()), CareTexts.alertBody(a), true, null);
    }

    private static Alert.Kind issueOf(CheckResult result, Alert.Kind issue) {
        if (result == CheckResult.ISSUE) {
            if (issue == null || issue == Alert.Kind.NOT_CONFIRMED) {
                throw ApiException.badRequest("validation", "Cần cho biết vấn đề là gì.");
            }
            return issue;
        }
        if (issue != null) throw ApiException.badRequest("validation", "Chỉ ghi vấn đề khi người già chọn có vấn đề.");
        return null;
    }

    private ElderProfile activeElder(Long elderUserId) {
        ElderProfile elder = elders.findById(elderUserId)
                .orElseThrow(() -> ApiException.forbidden("Chỉ máy của người già mới gửi được báo cáo này."));
        members.findByGroupIdAndUserIdAndLeftAtIsNull(elder.getGroupId(), elderUserId)
                .filter(m -> m.getRole() == GroupRole.ELDER)
                .orElseThrow(() -> ApiException.notFound("nhóm"));
        return elder;
    }

    private List<AlertResponse> toResponses(List<Alert> list) {
        if (list.isEmpty()) return List.of();
        List<Long> ids = list.stream().flatMap(a -> java.util.stream.Stream.of(a.getElderUserId(), a.getResolvedBy()))
                .filter(java.util.Objects::nonNull).distinct().toList();
        Map<Long, User> byId = users.findAllById(ids).stream().collect(Collectors.toMap(User::getId, Function.identity()));
        Map<Long, String> callNames = elders.findAllById(list.stream().map(Alert::getElderUserId).distinct().toList())
                .stream().collect(Collectors.toMap(ElderProfile::getUserId, ElderProfile::getCallName));
        return list.stream().map(a -> new AlertResponse(a.getId(), a.getElderUserId(),
                callNames.getOrDefault(a.getElderUserId(), name(byId.get(a.getElderUserId()))), a.getKind(),
                a.getMedicationId(), a.getMedicationNames(), a.getScheduledDate(),
                a.getScheduledTime() == null ? null : hhmm(a.getScheduledTime()), a.getCreatedAt(), a.getResolvedAt(),
                a.getResolvedBy(), a.getResolvedBy() == null ? null : name(byId.get(a.getResolvedBy())))).toList();
    }

    private static String name(User u) {
        return u == null ? "" : u.getDisplayName();
    }

    private static String hhmm(LocalTime t) {
        return t.toString().substring(0, 5);
    }
}
