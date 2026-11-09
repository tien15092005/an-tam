package vn.antam.chat;

import java.util.List;
import java.util.Map;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import vn.antam.auth.CurrentUser;
import vn.antam.chat.ChatService.MessageDto;
import vn.antam.chat.ChatService.SendRequest;

@RestController
@RequestMapping("/api")
public class ChatController {

    public record ReadRequest(@NotNull Long lastReadMessageId) {
    }

    private final ChatService chat;

    public ChatController(ChatService chat) {
        this.chat = chat;
    }

    /** Newest first; pass the smallest id you have as {@code before} for older ones. */
    @GetMapping("/groups/{groupId}/chat/messages")
    public List<MessageDto> history(@CurrentUser Long me, @PathVariable Long groupId,
                                    @RequestParam(required = false) Long before, @RequestParam(defaultValue = "30") int limit) {
        return chat.history(me, groupId, before, limit);
    }

    @PostMapping("/groups/{groupId}/chat/messages")
    public MessageDto send(@CurrentUser Long me, @PathVariable Long groupId, @Valid @RequestBody SendRequest r) {
        try {
            return chat.send(me, groupId, r);
        } catch (DataIntegrityViolationException raced) {
            return chat.send(me, groupId, r);
        }
    }

    @DeleteMapping("/groups/{groupId}/chat/messages/{messageId}")
    public ResponseEntity<Void> delete(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long messageId) {
        chat.delete(me, groupId, messageId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/groups/{groupId}/chat/read")
    public ResponseEntity<Void> read(@CurrentUser Long me, @PathVariable Long groupId, @Valid @RequestBody ReadRequest r) {
        chat.markRead(me, groupId, r.lastReadMessageId());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/me/chat/unread")
    public Map<Long, Long> unread(@CurrentUser Long me) {
        return chat.unread(me);
    }
}
