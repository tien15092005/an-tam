package vn.antam.group;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import vn.antam.auth.TokenService;
import vn.antam.user.User;
import vn.antam.user.UserRepository;

/**
 * Removes what identifies a parent or describes their health, when a family deletes them or the whole family.
 * <p>
 * Rows that other rows point to (medications, dose logs, alerts) are kept but emptied of names, notes and
 * descriptions, so counts and history still add up while nothing in them says who took what. Photo files are
 * marked deleted and removed from disk by the nightly job. Push texts are deleted; they repeat names.
 */
@Component
public class DataEraser {

    static final String ERASED_PERSON = "Người dùng đã xóa";
    static final String ERASED_MEDICINE = "Thuốc đã xóa";
    static final String ERASED_EXERCISE = "Bài tập đã xóa";

    private final JdbcTemplate jdbc;
    private final UserRepository users;
    private final TokenService tokens;

    public DataEraser(JdbcTemplate jdbc, UserRepository users, TokenService tokens) {
        this.jdbc = jdbc;
        this.users = users;
        this.tokens = tokens;
    }

    /** One parent: their profile, account, phone sessions, medicines, exercises and the history about them. */
    public void eraseElder(Long groupId, Long elderId, Instant now) {
        Timestamp ts = Timestamp.from(now);
        jdbc.update("""
                UPDATE medication_images SET deleted_at = ? WHERE deleted_at IS NULL
                  AND medication_id IN (SELECT id FROM medications WHERE elder_user_id = ?)
                """, ts, elderId);
        jdbc.update("""
                UPDATE audit_logs SET changes = NULL
                WHERE (entity_type = 'MEDICATION' AND entity_id IN (SELECT id FROM medications WHERE elder_user_id = ?))
                   OR (entity_type = 'EXERCISE' AND entity_id IN (SELECT id FROM exercises WHERE elder_user_id = ?))
                   OR (entity_type = 'DOSE_LOG' AND entity_id IN (SELECT id FROM dose_logs WHERE elder_user_id = ?))
                """, elderId, elderId, elderId);
        jdbc.update("""
                UPDATE medications SET active = false, name = ?, strength = NULL, dosage = NULL, note = NULL, shape = NULL,
                       color = NULL, imprint = NULL, pill_description = NULL
                WHERE elder_user_id = ?
                """, ERASED_MEDICINE, elderId);
        jdbc.update("UPDATE dose_logs SET name_snapshot = ?, dosage_snapshot = NULL WHERE elder_user_id = ?",
                ERASED_MEDICINE, elderId);
        jdbc.update("UPDATE exercises SET active = false, title = ?, note = NULL WHERE elder_user_id = ?",
                ERASED_EXERCISE, elderId);
        jdbc.update("UPDATE exercise_logs SET title_snapshot = ? WHERE elder_user_id = ?", ERASED_EXERCISE, elderId);
        jdbc.update("UPDATE alerts SET medication_names = NULL WHERE elder_user_id = ?", elderId);
        jdbc.update("""
                UPDATE elder_profiles SET call_name = ?, phone = NULL, health_note = NULL, birth_year = NULL
                WHERE user_id = ?
                """, ERASED_PERSON, elderId);
        // Push texts of this family name the parent and their medicines; once delivered they have no use.
        jdbc.update("DELETE FROM notification_outbox WHERE group_id = ? AND status <> 'PENDING'", groupId);
        jdbc.update("DELETE FROM notification_outbox WHERE user_id = ?", elderId);
        jdbc.update("DELETE FROM devices WHERE user_id = ?", elderId);
        tokens.revokeAll(elderId);
        users.findById(elderId).ifPresent(User::anonymize);
    }

    /** Push tokens of a phone that must stop receiving this account's notifications. */
    public void forgetDevices(Long userId) {
        jdbc.update("DELETE FROM devices WHERE user_id = ?", userId);
    }

    /** The whole family is gone: every parent in it, plus all its push texts and change history. */
    public void eraseGroup(Long groupId, List<Long> elderIds, Instant now) {
        for (Long elderId : elderIds) eraseElder(groupId, elderId, now);
        jdbc.update("DELETE FROM notification_outbox WHERE group_id = ?", groupId);
        jdbc.update("UPDATE audit_logs SET changes = NULL WHERE group_id = ?", groupId);
    }
}
