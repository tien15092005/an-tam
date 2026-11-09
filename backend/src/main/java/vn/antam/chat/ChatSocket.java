package vn.antam.chat;

import java.io.IOException;
import java.security.Principal;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Configuration;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;
import org.springframework.web.socket.handler.ConcurrentWebSocketSessionDecorator;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * Real-time chat at /ws/chat. The handshake goes through the normal security filter, so it needs the same
 * "Authorization: Bearer" token as REST. Protocol (JSON text frames):
 * <pre>
 *  → {"type":"subscribe","groupId":1}
 *  ← {"type":"subscribed","groupId":1}  or  {"type":"error","code":"not_found"}
 *  ← {"type":"message","message":{...}}   (new, or a deleted one with "deleted":true)
 * </pre>
 * Missed something while disconnected? The app fetches history over REST; the socket is only a fast path.
 */
@Component
public class ChatSocket extends TextWebSocketHandler {

    private static final Logger log = LoggerFactory.getLogger(ChatSocket.class);

    private final ChatService chat;
    private final JsonMapper json;
    /** groupId -> open sessions subscribed to it. */
    private final Map<Long, Set<WebSocketSession>> byGroup = new ConcurrentHashMap<>();

    public ChatSocket(ChatService chat, JsonMapper json) {
        this.chat = chat;
        this.json = json;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        if (userOf(session) == null) close(session);
    }

    @Override
    protected void handleTextMessage(WebSocketSession raw, TextMessage frame) throws IOException {
        Long userId = userOf(raw);
        JsonNode in;
        try {
            in = json.readTree(frame.getPayload());
        } catch (RuntimeException e) {
            send(raw, Map.of("type", "error", "code", "bad_json"));
            return;
        }
        if (!"subscribe".equals(in.path("type").asString(""))) {
            send(raw, Map.of("type", "error", "code", "unknown_type"));
            return;
        }
        long groupId = in.path("groupId").asLong(0);
        if (userId == null || groupId <= 0 || !chat.canRead(userId, groupId)) {
            send(raw, Map.of("type", "error", "code", "not_found", "groupId", groupId));
            return;
        }
        WebSocketSession session = wrap(raw);
        byGroup.computeIfAbsent(groupId, g -> ConcurrentHashMap.newKeySet()).add(session);
        send(session, Map.of("type", "subscribed", "groupId", groupId));
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        byGroup.values().forEach(set -> set.removeIf(s -> s.getId().equals(session.getId())));
    }

    /** After the message is committed, to every subscriber who is still allowed to read the group. */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onChanged(ChatService.Changed e) {
        Set<WebSocketSession> subscribers = byGroup.get(e.groupId());
        if (subscribers == null) return;
        for (WebSocketSession s : subscribers) {
            Long userId = userOf(s);
            if (!s.isOpen() || userId == null || !chat.canRead(userId, e.groupId())) {
                subscribers.remove(s); // left the group or was removed: no more messages
                continue;
            }
            send(s, Map.of("type", "message", "message", e.message()));
        }
    }

    private WebSocketSession wrap(WebSocketSession raw) {
        return raw instanceof ConcurrentWebSocketSessionDecorator ? raw
                : new ConcurrentWebSocketSessionDecorator(raw, 5_000, 256 * 1024);
    }

    private void send(WebSocketSession s, Object payload) {
        try {
            s.sendMessage(new TextMessage(json.writeValueAsString(payload)));
        } catch (IOException | RuntimeException e) {
            log.debug("chat socket send failed: {}", e.getClass().getSimpleName());
        }
    }

    private static Long userOf(WebSocketSession s) {
        Principal p = s.getPrincipal();
        try {
            return p == null ? null : Long.valueOf(p.getName());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static void close(WebSocketSession s) {
        try {
            s.close(CloseStatus.POLICY_VIOLATION);
        } catch (IOException ignored) {
            // already gone
        }
    }

    @Configuration
    @EnableWebSocket
    static class Config implements WebSocketConfigurer {

        private final ChatSocket socket;

        Config(ChatSocket socket) {
            this.socket = socket;
        }

        @Override
        public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
            registry.addHandler(socket, "/ws/chat");
        }
    }
}
