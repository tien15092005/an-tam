package vn.antam.notification;

import java.time.Clock;
import java.time.Instant;
import java.sql.Timestamp;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import vn.antam.group.GroupMember;
import vn.antam.group.GroupMemberRepository;
import vn.antam.group.GroupRole;

/**
 * Queues notifications in the caller's transaction (the outbox pattern): if the event rolls back, so
 * do its notifications, and nothing is lost if the push service is down. A repeated dedupe key is ignored.
 */
@Component
public class Notifier {

    /** What a push is about; the app decides what to do with it. */
    public enum Kind {
        /** Elder answered an alarm with no problem. */
        DOSE_REPORT,
        /** Any alert: a reported problem, "not feeling well", or not confirmed. */
        ALERT,
        /** A caregiver marked a dose for the elder: the elder's phone stops ringing. Data only. */
        DOSE_MARKED,
        /** The elder pressed "TÔI ĐI TẬP ĐÂY". */
        EXERCISE_REPORT,
        /** The schedule changed: the elder's phone downloads it again. Data only. */
        SCHEDULE_CHANGED
    }

    private final JdbcTemplate jdbc;
    private final GroupMemberRepository members;
    private final Clock clock;

    public Notifier(JdbcTemplate jdbc, GroupMemberRepository members, Clock clock) {
        this.jdbc = jdbc;
        this.members = members;
        this.clock = clock;
    }

    /** Every active owner and member of the group, except {@code except} (who caused the event). */
    public void toCaregivers(Long groupId, Kind kind, Long refId, String dedupe, String title, String body,
                             boolean urgent, Long except) {
        List<GroupMember> caregivers = members.findByGroupIdAndLeftAtIsNullOrderByJoinedAt(groupId).stream()
                .filter(m -> m.getRole() != GroupRole.ELDER && !m.getUserId().equals(except)).toList();
        for (GroupMember m : caregivers) {
            toUser(m.getUserId(), kind, groupId, refId, dedupe + ":" + m.getUserId(), title, body, urgent);
        }
    }

    public void toUser(Long userId, Kind kind, Long groupId, Long refId, String dedupeKey, String title, String body,
                       boolean urgent) {
        Instant now = clock.instant();
        jdbc.update("""
                INSERT INTO notification_outbox (dedupe_key, user_id, kind, group_id, ref_id, title, body, urgent, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (dedupe_key) DO NOTHING
                """, dedupeKey, userId, kind.name(), groupId, refId, title, body, urgent, Timestamp.from(now));
    }
}
