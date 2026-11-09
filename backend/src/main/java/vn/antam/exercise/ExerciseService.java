package vn.antam.exercise;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import vn.antam.common.ApiException;
import vn.antam.exercise.ExerciseDtos.ExerciseReportRequest;
import vn.antam.exercise.ExerciseDtos.ExerciseReportResult;
import vn.antam.exercise.ExerciseDtos.ExerciseRequest;
import vn.antam.exercise.ExerciseDtos.ExerciseResponse;
import vn.antam.exercise.ExerciseDtos.RecentExercise;
import vn.antam.group.ElderProfile;
import vn.antam.group.ElderProfileRepository;
import vn.antam.group.FamilyGroupRepository;
import vn.antam.group.GroupAccess;
import vn.antam.group.GroupMember;
import vn.antam.group.GroupMemberRepository;
import vn.antam.group.GroupRole;
import vn.antam.medication.AuditLog;
import vn.antam.medication.AuditLogRepository;
import vn.antam.medication.DoseLog;
import vn.antam.notification.Notifier;
import vn.antam.schedule.ScheduleExpander;

/** Exercise reminders (plan §5 matrix: the owner edits, everyone in the group sees, the elder confirms). */
@Service
public class ExerciseService {

    private final ExerciseRepository exercises;
    private final ExerciseLogRepository logs;
    private final GroupAccess access;
    private final GroupMemberRepository members;
    private final ElderProfileRepository elders;
    private final FamilyGroupRepository groups;
    private final AuditLogRepository audit;
    private final Notifier notifier;
    private final vn.antam.chat.ChatService chat;
    private final Clock clock;

    public ExerciseService(ExerciseRepository exercises, ExerciseLogRepository logs, GroupAccess access,
                           GroupMemberRepository members, ElderProfileRepository elders, FamilyGroupRepository groups,
                           AuditLogRepository audit, Notifier notifier, vn.antam.chat.ChatService chat, Clock clock) {
        this.exercises = exercises;
        this.logs = logs;
        this.access = access;
        this.members = members;
        this.elders = elders;
        this.groups = groups;
        this.audit = audit;
        this.notifier = notifier;
        this.chat = chat;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<ExerciseResponse> list(Long userId, Long groupId, Long elderUserId) {
        GroupMember me = access.requireMember(groupId, userId);
        if (me.getRole() == GroupRole.ELDER && !me.getUserId().equals(elderUserId)) {
            throw ApiException.forbidden("Bạn chỉ xem được lịch tập của mình.");
        }
        ElderProfile elder = elderInGroup(groupId, elderUserId);
        return exercises.current(elderUserId, today(elder)).stream().map(ExerciseService::toResponse).toList();
    }

    /** For the elder's phone, with the schedule. */
    @Transactional(readOnly = true)
    public List<ExerciseResponse> currentFor(ElderProfile elder) {
        return exercises.current(elder.getUserId(), today(elder)).stream().map(ExerciseService::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<RecentExercise> recentFor(ElderProfile elder) {
        LocalDate today = today(elder);
        return logs.findByElderUserIdAndScheduledDateBetweenOrderByScheduledDate(elder.getUserId(), today.minusDays(1), today)
                .stream().map(l -> new RecentExercise(l.getExerciseId(), l.getScheduledDate())).toList();
    }

    @Transactional
    public ExerciseResponse create(Long userId, Long groupId, Long elderUserId, ExerciseRequest r) {
        access.requireOwner(groupId, userId);
        ElderProfile elder = elderInGroup(groupId, elderUserId);
        Instant now = clock.instant();
        Exercise e = new Exercise(groupId, elderUserId, UUID.randomUUID(), userId, now);
        apply(e, r, r.startDate() == null ? today(elder) : r.startDate());
        exercises.save(e);
        changed(groupId, userId, "EXERCISE_CREATED", e, now);
        return toResponse(e);
    }

    /** Like medications: a change of time or weekdays after days were logged starts a new version today. */
    @Transactional
    public ExerciseResponse update(Long userId, Long groupId, Long exerciseId, ExerciseRequest r) {
        access.requireOwner(groupId, userId);
        Exercise current = inGroup(groupId, exerciseId);
        ElderProfile elder = elderInGroup(groupId, current.getElderUserId());
        LocalDate today = today(elder);
        Instant now = clock.instant();
        LocalTime time = LocalTime.parse(r.time());
        int mask = ScheduleExpander.maskOf(r.daysOfWeek());
        boolean newVersion = current.scheduleDiffers(time, mask) && current.getStartDate().isBefore(today)
                && logs.existsByExerciseId(current.getId());
        Exercise result = current;
        if (newVersion) {
            current.closeBefore(today);
            current.touch(userId, now);
            result = new Exercise(groupId, current.getElderUserId(), current.getSeriesId(), userId, now);
            LocalDate start = r.startDate() == null || r.startDate().isBefore(today) ? today : r.startDate();
            apply(result, r, start);
            exercises.save(result);
        } else {
            apply(current, r, r.startDate() == null ? current.getStartDate() : r.startDate());
            current.touch(userId, now);
        }
        changed(groupId, userId, newVersion ? "EXERCISE_NEW_VERSION" : "EXERCISE_UPDATED", result, now);
        return toResponse(result);
    }

    @Transactional
    public void delete(Long userId, Long groupId, Long exerciseId) {
        access.requireOwner(groupId, userId);
        Exercise e = inGroup(groupId, exerciseId);
        e.deactivate();
        e.touch(userId, clock.instant());
        changed(groupId, userId, "EXERCISE_DELETED", e, clock.instant());
    }

    /** First answer wins; a resend returns what was stored. */
    @Transactional
    public ExerciseReportResult report(Long elderUserId, ExerciseReportRequest r) {
        ElderProfile elder = elders.findById(elderUserId)
                .orElseThrow(() -> ApiException.forbidden("Chỉ máy của người già mới gửi được báo cáo này."));
        if (r.source() == DoseLog.Source.CAREGIVER) throw ApiException.badRequest("validation", "Nguồn không hợp lệ.");
        var same = logs.findByClientEventId(r.clientEventId());
        if (same.isPresent()) return new ExerciseReportResult(same.get().getId(), true);
        Exercise e = exercises.findById(r.exerciseId())
                .filter(x -> x.getElderUserId().equals(elderUserId) && x.getGroupId().equals(elder.getGroupId()))
                .orElseThrow(() -> ApiException.notFound("lịch tập"));
        boolean scheduled = !ScheduleExpander.occurrences(List.of(e.getTimeOfDay()), e.getDaysOfWeek(), e.getStartDate(),
                e.getEndDate(), r.scheduledDate(), r.scheduledDate()).isEmpty();
        if (!scheduled) throw ApiException.badRequest("not_scheduled", "Hôm đó không có lịch tập này.");
        var existing = logs.findByExerciseIdAndScheduledDate(e.getId(), r.scheduledDate());
        if (existing.isPresent()) return new ExerciseReportResult(existing.get().getId(), true);
        Instant now = clock.instant();
        ExerciseLog log = logs.save(new ExerciseLog(e, r.scheduledDate(), r.source(), r.clientEventId(), elderUserId, now));
        notifier.toCaregivers(elder.getGroupId(), Notifier.Kind.EXERCISE_REPORT, log.getId(), "exercise:" + r.clientEventId(),
                elder.getCallName() + " đã đi tập", e.getTitle() + " · " + e.getTimeOfDay().toString().substring(0, 5), false, null);
        return new ExerciseReportResult(log.getId(), false);
    }

    // ---- helpers

    private static String verb(String action) {
        if (action.endsWith("CREATED")) return "đã thêm";
        if (action.endsWith("DELETED")) return "đã xóa";
        if (action.contains("IMAGE")) return "đã đổi ảnh";
        return "đã sửa";
    }

    private static void apply(Exercise e, ExerciseRequest r, LocalDate start) {
        if (r.endDate() != null && r.endDate().isBefore(start)) {
            throw ApiException.badRequest("validation", "Ngày kết thúc phải sau ngày bắt đầu.");
        }
        e.apply(r.title().trim(), LocalTime.parse(r.time()), ScheduleExpander.maskOf(r.daysOfWeek()),
                r.durationMin() == null ? null : r.durationMin().shortValue(),
                r.note() == null || r.note().isBlank() ? null : r.note().trim(), start, r.endDate());
    }

    private void changed(Long groupId, Long userId, String action, Exercise e, Instant now) {
        var group = groups.findById(groupId).orElseThrow();
        group.bumpScheduleVersion();
        audit.save(new AuditLog(groupId, userId, action, "EXERCISE", e.getId(),
                "{\"title\":\"" + e.getTitle().replace("\\", "\\\\").replace("\"", "\\\"") + "\"}", now));
        notifier.toUser(e.getElderUserId(), Notifier.Kind.SCHEDULE_CHANGED, groupId, e.getId(),
                "schedule:" + groupId + ":" + group.getScheduleVersion() + ":" + e.getElderUserId(), null, null, false);
        chat.system(groupId, chat.nameOf(userId) + " " + verb(action) + " lịch tập " + e.getTitle(), null);
    }

    private Exercise inGroup(Long groupId, Long id) {
        return exercises.findById(id).filter(e -> e.getGroupId().equals(groupId) && e.isActive())
                .orElseThrow(() -> ApiException.notFound("lịch tập"));
    }

    private ElderProfile elderInGroup(Long groupId, Long elderUserId) {
        return members.findByGroupIdAndUserIdAndLeftAtIsNull(groupId, elderUserId)
                .filter(m -> m.getRole() == GroupRole.ELDER)
                .flatMap(m -> elders.findById(elderUserId))
                .orElseThrow(() -> ApiException.notFound("người già trong nhóm"));
    }

    private LocalDate today(ElderProfile elder) {
        return LocalDate.now(clock.withZone(ZoneId.of(elder.getTimezone())));
    }

    static ExerciseResponse toResponse(Exercise e) {
        List<Integer> days = new ArrayList<>();
        for (int d = 1; d <= 7; d++) if ((e.getDaysOfWeek() & (1 << (d - 1))) != 0) days.add(d);
        return new ExerciseResponse(e.getId(), e.getSeriesId(), e.getElderUserId(), e.getTitle(),
                e.getTimeOfDay().toString().substring(0, 5), days, e.getDurationMin() == null ? null : e.getDurationMin().intValue(),
                e.getNote(), e.getStartDate(), e.getEndDate(), e.getCreatedAt());
    }
}
