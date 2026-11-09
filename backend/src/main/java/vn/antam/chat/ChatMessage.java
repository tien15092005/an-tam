package vn.antam.chat;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "chat_messages")
public class ChatMessage {

    public enum Type { TEXT, SYSTEM }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "group_id", nullable = false)
    private Long groupId;

    @Column(name = "sender_id")
    private Long senderId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Type type;

    @Column(nullable = false)
    private String body;

    @Column(name = "alert_id")
    private Long alertId;

    @Column(name = "client_message_id")
    private UUID clientMessageId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "deleted_at")
    private Instant deletedAt;

    protected ChatMessage() {
    }

    public static ChatMessage text(Long groupId, Long senderId, String body, UUID clientMessageId, Instant now) {
        ChatMessage m = new ChatMessage();
        m.groupId = groupId;
        m.senderId = senderId;
        m.type = Type.TEXT;
        m.body = body;
        m.clientMessageId = clientMessageId;
        m.createdAt = now;
        return m;
    }

    public static ChatMessage system(Long groupId, String body, Long alertId, Instant now) {
        ChatMessage m = new ChatMessage();
        m.groupId = groupId;
        m.type = Type.SYSTEM;
        m.body = body.length() > 1000 ? body.substring(0, 1000) : body;
        m.alertId = alertId;
        m.createdAt = now;
        return m;
    }

    public void delete(Instant now) {
        if (deletedAt == null) deletedAt = now;
    }

    public Long getId() { return id; }
    public Long getGroupId() { return groupId; }
    public Long getSenderId() { return senderId; }
    public Type getType() { return type; }
    public String getBody() { return body; }
    public Long getAlertId() { return alertId; }
    public UUID getClientMessageId() { return clientMessageId; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getDeletedAt() { return deletedAt; }
}
