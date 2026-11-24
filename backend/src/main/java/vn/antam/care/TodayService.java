package vn.antam.care;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import vn.antam.care.CareDtos.CalendarDay;
import vn.antam.care.CareDtos.DayCounts;
import vn.antam.care.CareDtos.DaySlot;
import vn.antam.care.CareDtos.DayView;
import vn.antam.care.CareDtos.ExerciseSlot;
import vn.antam.care.CareDtos.MarkRequest;
import vn.antam.care.CareDtos.MarkResult;
import vn.antam.common.ApiException;
import vn.antam.exercise.Exercise;
import vn.antam.exercise.ExerciseLog;
import vn.antam.exercise.ExerciseLogRepository;
import vn.antam.exercise.ExerciseRepository;
import vn.antam.group.ElderProfile;
import vn.antam.group.ElderProfileRepository;
import vn.antam.group.GroupAccess;
import vn.antam.group.GroupMemberRepository;
import vn.antam.group.GroupRole;
import vn.antam.medication.AuditLog;
import vn.antam.medication.AuditLogRepository;
import vn.antam.medication.DoseLog;
import vn.antam.medication.DoseLogRepository;
import vn.antam.medication.Medication;
import vn.antam.medication.MedicationImage;
import vn.antam.medication.MedicationImageRepository;
import vn.antam.medication.MedicationRepository;
import vn.antam.notification.Notifier;
import vn.antam.schedule.DoseStatus;
import vn.antam.schedule.ScheduleExpander;
import vn.antam.user.User;
import vn.antam.user.UserRepository;

/** The caregiver's "Hôm nay" tab: one elder's day, and marking a dose on the elder's behalf (plan §10). */
@Service
public class TodayService {

    /** How far back a caregiver may mark or undo, and the window of the "missed" count. */
    static final int HISTORY_DAYS = 7;
    /** A pill handed over in person a little early can be marked before its time. */
    static final java.time.Duration MARK_AHEAD = java.time.Duration.ofHours(2);

    private final MedicationRepository medications;
    private final MedicationImageRepository images;
    private final DoseLogRepository doseLogs;
    private final AlertRepository alerts;
    private final ElderProfileRepository elders;
    private final GroupMemberRepository members;
    private final GroupAccess access;
    private final UserRepository users;
    private final AuditLogRepository audit;
    private final Notifier notifier;
    private final ExerciseRepository exercisesRepo;
    private final ExerciseLogRepository exerciseLogs;
    private final Clock clock;

    public TodayService(MedicationRepository medications, MedicationImageRepository images, DoseLogRepository doseLogs,
                        AlertRepository alerts, ElderProfileRepository elders, GroupMemberRepository members,
                        GroupAccess access, UserRepository users, AuditLogRepository audit, Notifier notifier,
                        ExerciseRepository exercisesRepo, ExerciseLogRepository exerciseLogs,
                        Clock clock) {
        this.medications = medications;
        this.images = images;
        this.doseLogs = doseLogs;
        this.alerts = alerts;
        this.elders = elders;
        this.members = members;
        this.access = access;
        this.users = users;
        this.audit = audit;
        this.notifier = notifier;
        this.exercisesRepo = exercisesRepo;
        this.exerciseLogs = exerciseLogs;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public DayView day(Long userId, Long groupId, Long elderUserId, LocalDate date) {
        access.requireCaregiver(groupId, userId);
        ElderProfile elder = elderInGroup(groupId, elderUserId);
        Window w = load(elder, date.minusDays(HISTORY_DAYS - 1), date);
        Set<Long> people = new HashSet<>();
        w.logs().forEach(l -> people.add(l.getLoggedBy()));
        w.exLogs().values().forEach(l -> people.add(l.getLoggedBy()));
        Map<Long, String> names = users.findAllById(people).stream().collect(Collectors.toMap(User::getId, User::getDisplayName));
        Map<Long, String> photo = firstPhotos(groupId, w.meds());

        int missedWeek = 0;
        for (LocalDate d = w.from(); !d.isAfter(date); d = d.plusDays(1)) {
            missedWeek += (int) medStatuses(w, d).values().stream().filter(st -> st == DoseStatus.MISSED).count();
        }
        List<DaySlot> slots = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        for (Medication m : w.meds()) {
            for (LocalDateTime due : occurrences(m, date)) {
                DoseLog log = w.logByKey().get(key(m.getId(), due));
                DoseStatus st = status(w, m, due, log);
                if (st == DoseStatus.NOT_APPLICABLE) continue;
                seen.add(key(m.getId(), due));
                slots.add(slot(m, due, st, log, names, photo.get(m.getId()), w.now()));
            }
        }
        // Logs of medicines deleted since (history stays truthful, plan §6).
        for (DoseLog log : w.logs()) {
            if (!log.getScheduledDate().equals(date) || seen.contains(key(log))) continue;
            slots.add(new DaySlot(CareTexts.hhmm(log.getScheduledTime()), log.getMedicationId(), log.getNameSnapshot(),
                    log.getDosageSnapshot(), null, null, DoseStatus.valueOf(log.getStatus().name()), log.getId(),
                    log.getSource(), log.getCheckResult(), log.getLoggedAt(), names.get(log.getLoggedBy()), false,
                    canUndo(log, w.now().toLocalDate())));
        }
        slots.sort(Comparator.comparing(DaySlot::scheduledTime).thenComparing(DaySlot::name));
        DayCounts counts = new DayCounts(slots.size(), count(slots, DoseStatus.TAKEN),
                count(slots, DoseStatus.NOT_TAKEN) + count(slots, DoseStatus.SKIPPED), count(slots, DoseStatus.MISSED),
                count(slots, DoseStatus.DUE), count(slots, DoseStatus.UPCOMING));
        List<ExerciseSlot> exercises = new ArrayList<>();
        for (Exercise e : w.exercises()) {
            for (LocalDateTime due : occurrences(e, date)) {
                ExerciseLog log = w.exLogs().get(e.getId() + "@" + date);
                String st = exerciseStatus(w, e, due, log);
                if (st == null) continue;
                exercises.add(new ExerciseSlot(e.getId(), e.getTitle(), CareTexts.hhmm(e.getTimeOfDay()),
                        e.getDurationMin() == null ? null : e.getDurationMin().intValue(), e.getNote(), st,
                        log == null ? null : log.getLoggedAt(), log == null ? null : log.getSource(),
                        log == null ? null : names.get(log.getLoggedBy())));
            }
        }
        int open = (int) alerts.countByGroupIdAndElderUserIdAndResolvedAtIsNull(groupId, elderUserId);
        return new DayView(date, elderUserId, elder.getCallName(), elder.getPhone(), slots, counts, missedWeek, open, exercises);
    }

    /** Status counts per day for the week / month calendar (plan §10: a dot per day). At most 62 days. */
    @Transactional(readOnly = true)
    public List<CalendarDay> calendar(Long userId, Long groupId, Long elderUserId, LocalDate from, LocalDate to) {
        access.requireCaregiver(groupId, userId);
        if (to.isBefore(from) || from.plusDays(62).isBefore(to)) {
            throw ApiException.badRequest("validation", "Khoảng ngày không hợp lệ (tối đa 62 ngày).");
        }
        ElderProfile elder = elderInGroup(groupId, elderUserId);
        Window w = load(elder, from, to);
        List<CalendarDay> out = new ArrayList<>();
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            Map<String, DoseStatus> st = medStatuses(w, d);
            // Deleted medicines still count for days they were logged.
            for (DoseLog log : w.logs()) {
                if (log.getScheduledDate().equals(d)) st.putIfAbsent(key(log), DoseStatus.valueOf(log.getStatus().name()));
            }
            int taken = 0, notTaken = 0, missed = 0, due = 0, upcoming = 0;
            for (DoseStatus s : st.values()) {
                switch (s) {
                    case TAKEN -> taken++;
                    case NOT_TAKEN, SKIPPED -> notTaken++;
                    case MISSED -> missed++;
                    case DUE -> due++;
                    case UPCOMING -> upcoming++;
                    default -> { }
                }
            }
            int ex = 0, exDone = 0, exMissed = 0;
            for (Exercise e : w.exercises()) {
                for (LocalDateTime when : occurrences(e, d)) {
                    String s = exerciseStatus(w, e, when, w.exLogs().get(e.getId() + "@" + d));
                    if (s == null) continue;
                    ex++;
                    if (s.equals("DONE")) exDone++;
                    if (s.equals("MISSED")) exMissed++;
                }
            }
            out.add(new CalendarDay(d, taken + notTaken + missed + due + upcoming, taken, notTaken, missed, due, upcoming,
                    ex, exDone, exMissed));
        }
        return out;
    }

    /** Everything needed to compute statuses for an elder over from..to, loaded once. */
    private record Window(LocalDate from, LocalDate to, ZoneId zone, LocalDateTime now, List<Medication> meds,
                          List<DoseLog> logs, Map<String, DoseLog> logByKey, List<Exercise> exercises,
                          Map<String, ExerciseLog> exLogs) {
    }

    private Window load(ElderProfile elder, LocalDate from, LocalDate to) {
        ZoneId zone = ZoneId.of(elder.getTimezone());
        List<DoseLog> logs = doseLogs.findByElderUserIdAndScheduledDateBetweenOrderByScheduledDateAscScheduledTimeAsc(
                elder.getUserId(), from, to);
        Map<String, ExerciseLog> exLogs = new HashMap<>();
        for (ExerciseLog l : exerciseLogs.findByElderUserIdAndScheduledDateBetweenOrderByScheduledDate(elder.getUserId(), from, to)) {
            exLogs.put(l.getExerciseId() + "@" + l.getScheduledDate(), l);
        }
        return new Window(from, to, zone, LocalDateTime.now(clock.withZone(zone)),
                medications.overlapping(elder.getUserId(), from, to), logs,
                logs.stream().collect(Collectors.toMap(TodayService::key, Function.identity(), (a, b) -> a)),
                exercisesRepo.overlapping(elder.getUserId(), from, to), exLogs);
    }

    /** Status of every applicable dose on one day, keyed like the logs. */
    private Map<String, DoseStatus> medStatuses(Window w, LocalDate d) {
        Map<String, DoseStatus> out = new HashMap<>();
        for (Medication m : w.meds()) {
            for (LocalDateTime due : occurrences(m, d)) {
                DoseStatus st = status(w, m, due, w.logByKey().get(key(m.getId(), due)));
                if (st != DoseStatus.NOT_APPLICABLE) out.put(key(m.getId(), due), st);
            }
        }
        return out;
    }

    private static DoseStatus status(Window w, Medication m, LocalDateTime due, DoseLog log) {
        return DoseStatus.of(due, w.now(), LocalDateTime.ofInstant(m.getCreatedAt(), w.zone()),
                log == null ? null : log.getStatus().name());
    }

    /** DONE, UPCOMING, DUE, MISSED, or null when the exercise was added after that time. */
    private static String exerciseStatus(Window w, Exercise e, LocalDateTime due, ExerciseLog log) {
        if (log != null) return "DONE";
        DoseStatus st = DoseStatus.of(due, w.now(), LocalDateTime.ofInstant(e.getCreatedAt(), w.zone()), null);
        return st == DoseStatus.NOT_APPLICABLE ? null : st.name();
    }

    private static List<LocalDateTime> occurrences(Medication m, LocalDate d) {
        return ScheduleExpander.occurrences(m.timeList(), m.getDaysOfWeek(), m.getStartDate(), m.getEndDate(), d, d);
    }

    private static List<LocalDateTime> occurrences(Exercise e, LocalDate d) {
        return ScheduleExpander.occurrences(List.of(e.getTimeOfDay()), e.getDaysOfWeek(), e.getStartDate(), e.getEndDate(), d, d);
    }

    /**
     * Marks the dose taken for every listed medicine at that time. First answer wins: a dose the elder (or
     * another caregiver) already answered is left as it is. The elder's phone is told to stop ringing.
     */
    @Transactional
    public MarkResult mark(Long userId, Long groupId, Long elderUserId, MarkRequest r) {
        access.requireCaregiver(groupId, userId);
        ElderProfile elder = elderInGroup(groupId, elderUserId);
        ZoneId zone = ZoneId.of(elder.getTimezone());
        LocalDateTime now = LocalDateTime.now(clock.withZone(zone));
        LocalTime time = LocalTime.parse(r.scheduledTime());
        LocalDateTime due = r.scheduledDate().atTime(time);
        if (due.isAfter(now.plus(MARK_AHEAD))) {
            throw ApiException.badRequest("too_early", "Chưa tới giờ uống, chưa đánh dấu được.");
        }
        if (r.scheduledDate().isBefore(now.toLocalDate().minusDays(HISTORY_DAYS - 1))) {
            throw ApiException.badRequest("too_old", "Chỉ đánh dấu được trong " + HISTORY_DAYS + " ngày gần đây.");
        }
        Instant at = clock.instant();
        List<Long> marked = new ArrayList<>();
        List<Long> already = new ArrayList<>();
        List<String> names = new ArrayList<>();
        for (Long medId : r.medicationIds().stream().distinct().toList()) {
            Medication m = medications.findById(medId)
                    .filter(x -> x.getElderUserId().equals(elderUserId) && x.getGroupId().equals(groupId) && x.isActive())
                    .orElseThrow(() -> ApiException.notFound("thuốc"));
            boolean scheduled = !ScheduleExpander.occurrences(m.timeList(), m.getDaysOfWeek(), m.getStartDate(), m.getEndDate(),
                    r.scheduledDate(), r.scheduledDate()).stream().filter(due::equals).toList().isEmpty();
            if (!scheduled) throw ApiException.badRequest("not_scheduled", "Thuốc " + m.getName() + " không có lịch vào giờ này.");
            var existing = doseLogs.findByMedicationIdAndScheduledDateAndScheduledTime(medId, r.scheduledDate(), time)
                    .or(() -> doseLogs.findByClientEventId(CareService.doseEventId(r.clientEventId(), medId)));
            if (existing.isPresent()) {
                already.add(existing.get().getId());
                continue;
            }
            DoseLog log = doseLogs.save(new DoseLog(m, r.scheduledDate(), time, DoseLog.Status.TAKEN, DoseLog.Source.CAREGIVER,
                    CareService.doseEventId(r.clientEventId(), medId), userId, at));
            marked.add(log.getId());
            names.add(m.getName());
            audit.save(new AuditLog(groupId, userId, "DOSE_MARKED", "DOSE_LOG", log.getId(),
                    "{\"date\":\"" + r.scheduledDate() + "\",\"time\":\"" + r.scheduledTime() + "\"}", at));
        }
        if (!marked.isEmpty()) {
            resolveNotConfirmedIfAnswered(elderUserId, r.scheduledDate(), time, userId, at);
            String caregiver = users.findById(userId).map(User::getDisplayName).orElse("Người con");
            String key = "marked:" + r.clientEventId();
            notifier.toUser(elderUserId, Notifier.Kind.DOSE_MARKED, groupId, marked.getFirst(), key, null, null, true);
            notifier.toCaregivers(groupId, Notifier.Kind.DOSE_REPORT, marked.getFirst(), key,
                    CareTexts.markedTitle(caregiver, elder.getCallName()),
                    r.scheduledTime() + " · " + String.join(", ", names) + " · đã uống", false, userId);
        }
        return new MarkResult(marked, already);
    }

    /** Undo a caregiver's mark (e.g. tapped the wrong row). The elder's own answers cannot be undone here. */
    @Transactional
    public void undo(Long userId, Long groupId, Long elderUserId, Long doseLogId) {
        access.requireCaregiver(groupId, userId);
        ElderProfile elder = elderInGroup(groupId, elderUserId);
        LocalDate today = LocalDate.now(clock.withZone(ZoneId.of(elder.getTimezone())));
        DoseLog log = doseLogs.findById(doseLogId).filter(d -> d.getElderUserId().equals(elderUserId))
                .orElseThrow(() -> ApiException.notFound("ghi nhận"));
        if (!canUndo(log, today)) {
            throw ApiException.forbidden("Chỉ hoàn tác được lần đánh dấu giúp trong " + HISTORY_DAYS + " ngày gần đây.");
        }
        alerts.detachDoseLog(log.getId());
        doseLogs.delete(log);
        Instant at = clock.instant();
        audit.save(new AuditLog(groupId, userId, "DOSE_UNMARKED", "DOSE_LOG", log.getId(),
                "{\"date\":\"" + log.getScheduledDate() + "\",\"time\":\"" + CareTexts.hhmm(log.getScheduledTime()) + "\"}", at));
        // The elder's phone reloads, so a future dose gets its alarm back.
        notifier.toUser(elderUserId, Notifier.Kind.SCHEDULE_CHANGED, groupId, log.getId(), "unmarked:" + log.getId(), null, null,
                false);
    }

    /** A NOT_CONFIRMED alert closes itself once every medicine of that time has an answer. */
    /** @return true when an open "chưa xác nhận" alert for that dose was settled by this answer. */
    boolean resolveNotConfirmedIfAnswered(Long elderUserId, LocalDate date, LocalTime time, Long by, Instant at) {
        return alerts.findByElderUserIdAndKindAndScheduledDateAndScheduledTimeAndResolvedAtIsNull(elderUserId,
                Alert.Kind.NOT_CONFIRMED, date, time).map(a -> {
            boolean allAnswered = medications.overlapping(elderUserId, date, date).stream()
                    .filter(m -> ScheduleExpander.occurrences(m.timeList(), m.getDaysOfWeek(), m.getStartDate(), m.getEndDate(),
                            date, date).contains(date.atTime(time)))
                    .allMatch(m -> doseLogs.findByMedicationIdAndScheduledDateAndScheduledTime(m.getId(), date, time).isPresent());
            if (allAnswered) a.resolve(by, at);
            return allAnswered;
        }).orElse(false);
    }

    // ---- helpers

    private DaySlot slot(Medication m, LocalDateTime due, DoseStatus st, DoseLog log, Map<Long, String> names, String imageUrl,
                         LocalDateTime now) {
        String description = java.util.stream.Stream.of(m.getPillDescription(), m.getShape(), m.getColor(), m.getImprint())
                .filter(s -> s != null && !s.isBlank()).collect(Collectors.joining(", "));
        boolean canMark = log == null && !due.isAfter(now.plus(MARK_AHEAD));
        return new DaySlot(CareTexts.hhmm(due.toLocalTime()), m.getId(), m.getName(), m.getDosage(),
                description.isEmpty() ? null : description, imageUrl, st, log == null ? null : log.getId(),
                log == null ? null : log.getSource(), log == null ? null : log.getCheckResult(),
                log == null ? null : log.getLoggedAt(), log == null ? null : names.get(log.getLoggedBy()), canMark,
                log != null && canUndo(log, now.toLocalDate()));
    }

    private static boolean canUndo(DoseLog log, LocalDate today) {
        return log.getSource() == DoseLog.Source.CAREGIVER && !log.getScheduledDate().isBefore(today.minusDays(HISTORY_DAYS - 1));
    }

    private Map<Long, String> firstPhotos(Long groupId, List<Medication> meds) {
        Map<Long, String> out = new HashMap<>();
        if (meds.isEmpty()) return out;
        for (MedicationImage i : images.findByMedicationIdInAndDeletedAtIsNullOrderBySortOrder(meds.stream().map(Medication::getId).toList())) {
            out.putIfAbsent(i.getMedicationId(), "/api/groups/" + groupId + "/medication-images/" + i.getId());
        }
        return out;
    }

    private ElderProfile elderInGroup(Long groupId, Long elderUserId) {
        return members.findByGroupIdAndUserIdAndLeftAtIsNull(groupId, elderUserId)
                .filter(m -> m.getRole() == GroupRole.ELDER)
                .flatMap(m -> elders.findById(elderUserId))
                .orElseThrow(() -> ApiException.notFound("người già trong nhóm"));
    }

    private static int count(List<DaySlot> slots, DoseStatus s) {
        return (int) slots.stream().filter(x -> x.status() == s).count();
    }

    private static String key(Long medId, LocalDateTime due) {
        return medId + "@" + due;
    }

    private static String key(DoseLog d) {
        return key(d.getMedicationId(), d.getScheduledDate().atTime(d.getScheduledTime()));
    }
}
