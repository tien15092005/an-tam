package vn.antam.chat;

import java.time.Clock;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import vn.antam.common.ApiException;
import vn.antam.group.FamilyGroupRepository;
import vn.antam.group.GroupAccess;
import vn.antam.group.GroupMember;
import vn.antam.group.GroupMemberRepository;
import vn.antam.group.GroupRole;
import vn.antam.notification.Notifier;
import vn.antam.user.User;
import vn.antam.user.UserRepository;

/**
 * Group chat between caregivers (plan §10): text only, delete your own, system lines for alerts and changes.
 * Elders never see it. Every read and write checks membership; the socket checks again on each delivery.
 */
@Service
public class ChatService {

    public record SendRequest(@NotNull UUID clientMessageId, @NotBlank @Size(max = 1000) String body) {
    }

    public record MessageDto(Long id, Long groupId, Long senderId, String senderName, ChatMessage.Type type, String body,
                             Long alertId, UUID clientMessageId, Instant createdAt, boolean deleted) {
    }

    /** Published inside the transaction; the socket handler sends it after commit. */
    public record Changed(Long groupId, MessageDto message) {
    }

    private final ChatMessageRepository messages;
    private final GroupAccess access;
    private final GroupMemberRepository members;
    private final FamilyGroupRepository groups;
    private final UserRepository users;
    private final JdbcTemplate jdbc;
    private final Notifier notifier;
    private final ApplicationEventPublisher events;
    private final Clock clock;

    public ChatService(ChatMessageRepository messages, GroupAccess access, GroupMemberRepository members,
                       FamilyGroupRepository groups, UserRepository users, JdbcTemplate jdbc, Notifier notifier,
                       ApplicationEventPublisher events, Clock clock) {
        this.messages = messages;
        this.access = access;
        this.members = members;
        this.groups = groups;
        this.users = users;
        this.jdbc = jdbc;
        this.notifier = notifier;
        this.events = events;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<MessageDto> history(Long userId, Long groupId, Long before, int limit) {
        access.requireCaregiver(groupId, userId);
        List<ChatMessage> page = messages.page(groupId, before == null ? Long.MAX_VALUE : before,
                PageRequest.of(0, Math.max(1, Math.min(limit, 50))));
        return toDtos(page);
    }

    /** A resend with the same clientMessageId returns the message already stored. */
    @Transactional
    public MessageDto send(Long userId, Long groupId, SendRequest r) {
        access.requireCaregiver(groupId, userId);
        var existing = messages.findBySenderIdAndClientMessageId(userId, r.clientMessageId());
        if (existing.isPresent()) {
            if (!existing.get().getGroupId().equals(groupId)) throw ApiException.conflict("duplicate", "Tin nhắn đã gửi ở nhóm khác.");
            return toDtos(List.of(existing.get())).getFirst();
        }
        ChatMessage m = messages.save(ChatMessage.text(groupId, userId, r.body().strip(), r.clientMessageId(), clock.instant()));
        MessageDto dto = toDtos(List.of(m)).getFirst();
        markRead(userId, groupId, m.getId());
        String groupName = groups.findById(groupId).map(g -> g.getName()).orElse("");
        notifier.toCaregivers(groupId, Notifier.Kind.CHAT, m.getId(), "chat:" + m.getId(), dto.senderName() + " · " + groupName,
                preview(m.getBody()), false, userId);
        events.publishEvent(new Changed(groupId, dto));
        return dto;
    }

    @Transactional
    public void delete(Long userId, Long groupId, Long messageId) {
        access.requireCaregiver(groupId, userId);
        ChatMessage m = messages.findById(messageId).filter(x -> x.getGroupId().equals(groupId))
                .orElseThrow(() -> ApiException.notFound("tin nhắn"));
        if (!userId.equals(m.getSenderId())) throw ApiException.forbidden("Chỉ người gửi mới xóa được tin nhắn.");
        m.delete(clock.instant());
        events.publishEvent(new Changed(groupId, toDtos(List.of(m)).getFirst()));
    }

    @Transactional
    public void markRead(Long userId, Long groupId, Long lastReadMessageId) {
        access.requireCaregiver(groupId, userId);
        // Never moves backwards (two phones of the same person may report out of order).
        jdbc.update("""
                INSERT INTO chat_read_states (group_id, user_id, last_read_message_id) VALUES (?, ?, ?)
                ON CONFLICT (group_id, user_id) DO UPDATE
                SET last_read_message_id = GREATEST(chat_read_states.last_read_message_id, EXCLUDED.last_read_message_id)
                """, groupId, userId, lastReadMessageId);
    }

    /** Unread counts for every group of this caregiver. */
    @Transactional(readOnly = true)
    public Map<Long, Long> unread(Long userId) {
        Map<Long, Long> out = new HashMap<>();
        for (GroupMember m : members.findByUserIdAndLeftAtIsNull(userId)) {
            if (m.getRole() == GroupRole.ELDER) continue;
            Long last = jdbc.query("SELECT last_read_message_id FROM chat_read_states WHERE group_id = ? AND user_id = ?",
                    rs -> rs.next() ? rs.getLong(1) : 0L, m.getGroupId(), userId);
            out.put(m.getGroupId(), messages.unread(m.getGroupId(), last, userId));
        }
        return out;
    }

    /** A system line ("Bà Lan báo hết thuốc Metformin"), joined to the caller's transaction. */
    @Transactional
    public void system(Long groupId, String body, Long alertId) {
        ChatMessage m = messages.save(ChatMessage.system(groupId, body, alertId, clock.instant()));
        events.publishEvent(new Changed(groupId, toDtos(List.of(m)).getFirst()));
    }

    /** "Chị Hoa" for system lines about who changed what. */
    @Transactional(readOnly = true)
    public String nameOf(Long userId) {
        return users.findById(userId).map(User::getDisplayName).orElse("Một người con");
    }

    /** True when this user may receive this group's messages right now (checked on every socket delivery). */
    @Transactional(readOnly = true)
    public boolean canRead(Long userId, Long groupId) {
        try {
            access.requireCaregiver(groupId, userId);
            return true;
        } catch (ApiException e) {
            return false;
        }
    }

    private List<MessageDto> toDtos(List<ChatMessage> list) {
        Map<Long, User> byId = users.findAllById(list.stream().map(ChatMessage::getSenderId).filter(java.util.Objects::nonNull)
                .distinct().toList()).stream().collect(Collectors.toMap(User::getId, Function.identity()));
        return list.stream().map(m -> new MessageDto(m.getId(), m.getGroupId(), m.getSenderId(),
                m.getSenderId() == null ? null : byId.containsKey(m.getSenderId()) ? byId.get(m.getSenderId()).getDisplayName() : "",
                m.getType(), m.getDeletedAt() == null ? m.getBody() : null, m.getAlertId(), m.getClientMessageId(),
                m.getCreatedAt(), m.getDeletedAt() != null)).toList();
    }

    private static String preview(String body) {
        return body.length() > 120 ? body.substring(0, 117) + "..." : body;
    }
}
