package vn.antam.chat;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import vn.antam.IntegrationTest;

/** Phase 9 DoD (REST part): outsiders cannot read, resends never duplicate, unread counts, system lines. */
class ChatTest extends IntegrationTest {

    Account owner;
    Account member;
    Account outsider;
    Account elder;
    Long groupId;
    Long elderId;
    String url;

    @BeforeEach
    void family() throws Exception {
        owner = registerCaregiver("Chi Hoa");
        member = registerCaregiver("Anh Nam");
        outsider = registerCaregiver("Nguoi La");
        groupId = readId(body(mvc.perform(json(as(owner, post("/api/groups")), "{\"name\":\"Nhà bà Lan\"}")).andReturn()), "$.id");
        String invite = read(body(mvc.perform(as(owner, post("/api/groups/" + groupId + "/invites"))).andReturn()), "$.code");
        mvc.perform(json(as(member, post("/api/invites/accept")), "{\"code\":\"" + invite + "\"}")).andExpect(status().isOk());
        elderId = readId(body(mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/elders")), "{\"callName\":\"Bà Lan\"}"))
                .andReturn()), "$.userId");
        String code = read(body(mvc.perform(as(owner, post("/api/groups/" + groupId + "/elders/" + elderId + "/pairing-code")))
                .andReturn()), "$.code");
        String pair = body(mvc.perform(json(post("/api/auth/elder-pair"), "{\"code\":\"" + code + "\",\"deviceName\":\"T\"}")).andReturn());
        String token = read(pair, "$.accessToken");
        elder = new Account(meId(token), token, read(pair, "$.refreshToken"));
        url = "/api/groups/" + groupId + "/chat/messages";
    }

    private String msg(UUID id, String body) {
        return "{\"clientMessageId\":\"" + id + "\",\"body\":\"" + body + "\"}";
    }

    @Test
    void onlyCaregiversOfTheGroupReadOrWrite() throws Exception {
        mvc.perform(json(as(outsider, post(url)), msg(UUID.randomUUID(), "xin chào"))).andExpect(status().isNotFound());
        mvc.perform(as(outsider, get(url))).andExpect(status().isNotFound());
        mvc.perform(json(as(elder, post(url)), msg(UUID.randomUUID(), "xin chào"))).andExpect(status().isForbidden());
        mvc.perform(as(elder, get(url))).andExpect(status().isForbidden());
        mvc.perform(json(as(member, post(url)), msg(UUID.randomUUID(), ""))).andExpect(status().isBadRequest());
        mvc.perform(json(as(member, post(url)), msg(UUID.randomUUID(), "x".repeat(1001)))).andExpect(status().isBadRequest());
    }

    @Test
    void aResendAfterADroppedConnectionIsNotPostedTwice() throws Exception {
        UUID id = UUID.randomUUID();
        Long first = readId(body(mvc.perform(json(as(member, post(url)), msg(id, "Mẹ uống thuốc chưa?")))
                .andExpect(status().isOk()).andReturn()), "$.id");
        Long again = readId(body(mvc.perform(json(as(member, post(url)), msg(id, "Mẹ uống thuốc chưa?")))
                .andExpect(status().isOk()).andReturn()), "$.id");
        assertThat(again).isEqualTo(first);
        mvc.perform(as(owner, get(url))).andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].senderName").value("Anh Nam"))
                .andExpect(jsonPath("$[0].body").value("Mẹ uống thuốc chưa?"));
    }

    @Test
    void historyPagesBackwardsAndUnreadCountsOthersMessages() throws Exception {
        for (int i = 1; i <= 5; i++) {
            mvc.perform(json(as(member, post(url)), msg(UUID.randomUUID(), "tin " + i))).andExpect(status().isOk());
        }
        String page1 = body(mvc.perform(as(owner, get(url + "?limit=3"))).andReturn());
        List<String> bodies = read(page1, "$[*].body");
        assertThat(bodies).containsExactly("tin 5", "tin 4", "tin 3");
        Long oldest = readId(page1, "$[2].id");
        List<String> older = read(body(mvc.perform(as(owner, get(url + "?limit=3&before=" + oldest))).andReturn()), "$[*].body");
        assertThat(older).containsExactly("tin 2", "tin 1");

        assertThat(((Number) read(body(mvc.perform(as(owner, get("/api/me/chat/unread"))).andReturn()), "$." + groupId)).intValue())
                .isEqualTo(5);
        assertThat(((Number) read(body(mvc.perform(as(member, get("/api/me/chat/unread"))).andReturn()), "$." + groupId)).intValue())
                .isZero(); // your own messages are read
        Long newest = readId(page1, "$[0].id");
        mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/chat/read")), "{\"lastReadMessageId\":" + newest + "}"))
                .andExpect(status().isNoContent());
        // An older read report (another phone) never moves it back.
        mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/chat/read")), "{\"lastReadMessageId\":" + oldest + "}"))
                .andExpect(status().isNoContent());
        assertThat(((Number) read(body(mvc.perform(as(owner, get("/api/me/chat/unread"))).andReturn()), "$." + groupId)).intValue())
                .isZero();
    }

    @Test
    void onlyTheSenderDeletesAndTheTextIsGoneForEveryone() throws Exception {
        Long id = readId(body(mvc.perform(json(as(member, post(url)), msg(UUID.randomUUID(), "nhầm nhóm"))).andReturn()), "$.id");
        mvc.perform(as(owner, delete(url + "/" + id))).andExpect(status().isForbidden());
        mvc.perform(as(member, delete(url + "/" + id))).andExpect(status().isNoContent());
        mvc.perform(as(owner, get(url))).andExpect(jsonPath("$[0].deleted").value(true))
                .andExpect(jsonPath("$[0].body").doesNotExist());
    }

    @Test
    void alertsAndScheduleChangesAppearAsSystemLines() throws Exception {
        mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/elders/" + elderId + "/medications")),
                "{\"name\":\"Metformin\",\"times\":[\"08:00\"]}")).andExpect(status().isCreated());
        mvc.perform(json(as(elder, post("/api/me/alerts")), "{\"clientEventId\":\"" + UUID.randomUUID() + "\",\"kind\":\"UNWELL\"}"))
                .andExpect(status().isOk());
        String history = body(mvc.perform(as(member, get(url))).andReturn());
        List<String> lines = read(history, "$[*].body");
        assertThat(lines).containsExactly("Bà Lan báo không khỏe", "Chi Hoa đã thêm thuốc Metformin");
        List<String> types = read(history, "$[*].type");
        assertThat(types).containsOnly("SYSTEM");
        assertThat((Object) read(history, "$[0].alertId")).isNotNull();
    }
}
