package vn.antam.care;

import java.sql.Date;
import java.sql.Time;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import vn.antam.group.ElderProfile;
import vn.antam.group.ElderProfileRepository;
import vn.antam.group.FamilyGroupRepository;
import vn.antam.group.GroupMemberRepository;
import vn.antam.group.GroupRole;
import vn.antam.medication.DoseLogRepository;
import vn.antam.medication.Medication;
import vn.antam.medication.MedicationRepository;
import vn.antam.notification.Notifier;
import vn.antam.schedule.DoseStatus;
import vn.antam.schedule.ScheduleExpander;

/**
 * Raises NOT_CONFIRMED when a dose time is more than 60 minutes past with no answer (plan §9). Runs every
 * minute and looks back {@link #LOOK_BACK}, so doses missed while the laptop was off are caught up on start.
 * The elder's phone keeps ringing regardless: this only tells the caregivers.
 */
@Component
public class DoseSweeper {

    private static final Logger log = LoggerFactory.getLogger(DoseSweeper.class);

    static final Duration LOOK_BACK = Duration.ofHours(24);

    private final ElderProfileRepository elders;
    private final GroupMemberRepository members;
    private final FamilyGroupRepository groups;
    private final MedicationRepository medications;
    private final DoseLogRepository doseLogs;
    private final JdbcTemplate jdbc;
    private final Notifier notifier;
    private final vn.antam.chat.ChatService chat;

    public DoseSweeper(ElderProfileRepository elders, GroupMemberRepository members, FamilyGroupRepository groups,
                       MedicationRepository medications, DoseLogRepository doseLogs, JdbcTemplate jdbc, Notifier notifier,
                       vn.antam.chat.ChatService chat) {
        this.elders = elders;
        this.members = members;
        this.groups = groups;
        this.medications = medications;
        this.doseLogs = doseLogs;
        this.jdbc = jdbc;
        this.notifier = notifier;
        this.chat = chat;
    }

    /** @return ids of the alerts created by this run */
    @Transactional
    public List<Long> sweep(Instant now) {
        List<Long> created = new ArrayList<>();
        for (ElderProfile elder : elders.findAll()) {
            boolean active = members.findByGroupIdAndUserIdAndLeftAtIsNull(elder.getGroupId(), elder.getUserId())
                    .filter(m -> m.getRole() == GroupRole.ELDER).isPresent()
                    && groups.findById(elder.getGroupId()).filter(g -> !g.isDeleted()).isPresent();
            if (active) created.addAll(sweepElder(elder, now));
        }
        if (!created.isEmpty()) log.info("Raised {} not-confirmed alert(s)", created.size());
        return created;
    }

    private List<Long> sweepElder(ElderProfile elder, Instant now) {
        ZoneId zone = ZoneId.of(elder.getTimezone());
        LocalDateTime nowLocal = LocalDateTime.ofInstant(now, zone);
        LocalDateTime from = LocalDateTime.ofInstant(now.minus(LOOK_BACK), zone);
        List<Medication> meds = medications.overlapping(elder.getUserId(), from.toLocalDate(), nowLocal.toLocalDate());
        if (meds.isEmpty()) return List.of();
        Set<String> answered = doseLogs.findByElderUserIdAndScheduledDateBetweenOrderByScheduledDateAscScheduledTimeAsc(
                        elder.getUserId(), from.toLocalDate(), nowLocal.toLocalDate()).stream()
                .map(d -> d.getMedicationId() + "@" + d.getScheduledDate().atTime(d.getScheduledTime()))
                .collect(Collectors.toSet());

        // Unanswered medicines grouped by their dose time (one alarm, one alert).
        Map<LocalDateTime, List<Medication>> open = new TreeMap<>();
        for (Medication m : meds) {
            LocalDateTime createdLocal = LocalDateTime.ofInstant(m.getCreatedAt(), zone);
            for (LocalDateTime due : ScheduleExpander.occurrences(m.timeList(), m.getDaysOfWeek(), m.getStartDate(),
                    m.getEndDate(), from.toLocalDate(), nowLocal.toLocalDate())) {
                if (due.isBefore(from)) continue;
                if (DoseStatus.of(due, nowLocal, createdLocal, null) != DoseStatus.MISSED) continue;
                if (answered.contains(m.getId() + "@" + due)) continue;
                open.computeIfAbsent(due, k -> new ArrayList<>()).add(m);
            }
        }
        List<Long> created = new ArrayList<>();
        for (var e : open.entrySet()) {
            List<Medication> list = e.getValue();
            String names = list.stream().map(Medication::getName).collect(Collectors.joining(", "));
            // The partial unique index makes a second run (or a second backend) a no-op.
            List<Long> ids = jdbc.queryForList("""
                    INSERT INTO alerts (group_id, elder_user_id, kind, medication_id, medication_names, scheduled_date,
                                        scheduled_time, created_at)
                    VALUES (?, ?, 'NOT_CONFIRMED', ?, ?, ?, ?, ?)
                    ON CONFLICT (elder_user_id, scheduled_date, scheduled_time) WHERE kind = 'NOT_CONFIRMED' DO NOTHING
                    RETURNING id
                    """, Long.class, elder.getGroupId(), elder.getUserId(), list.size() == 1 ? list.getFirst().getId() : null,
                    names.length() > 400 ? names.substring(0, 400) : names, Date.valueOf(e.getKey().toLocalDate()),
                    Time.valueOf(e.getKey().toLocalTime()), Timestamp.from(now));
            for (Long id : ids) {
                created.add(id);
                Alert shape = new Alert(elder.getGroupId(), elder.getUserId(), Alert.Kind.NOT_CONFIRMED, null, now);
                shape.aboutDose(null, null, names, e.getKey().toLocalDate(), e.getKey().toLocalTime());
                notifier.toCaregivers(elder.getGroupId(), Notifier.Kind.ALERT, id, "alert:" + id,
                        CareTexts.alertTitle(elder.getCallName(), Alert.Kind.NOT_CONFIRMED), CareTexts.alertBody(shape), true, null);
                chat.system(elder.getGroupId(), CareTexts.alertTitle(elder.getCallName(), Alert.Kind.NOT_CONFIRMED) + " " + names
                        + " (liều " + CareTexts.hhmm(e.getKey().toLocalTime()) + ")", id);
            }
        }
        return created;
    }
}
