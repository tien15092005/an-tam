package vn.antam.chat;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {

    Optional<ChatMessage> findBySenderIdAndClientMessageId(Long senderId, UUID clientMessageId);

    /** Newest first, older than {@code before} (cursor paging). */
    @Query("select m from ChatMessage m where m.groupId = :g and m.id < :before order by m.id desc")
    List<ChatMessage> page(@Param("g") Long groupId, @Param("before") Long before, Pageable page);

    @Query("""
            select count(m) from ChatMessage m
            where m.groupId = :g and m.id > :after and m.deletedAt is null
              and (m.senderId is null or m.senderId <> :me)
            """)
    long unread(@Param("g") Long groupId, @Param("after") Long afterId, @Param("me") Long userId);
}
