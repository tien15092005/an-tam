package vn.antam.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;

import vn.antam.IntegrationTest;

/** Phase 11: deleting an account removes the person's data and ends every session. */
class AccountDeletionTest extends IntegrationTest {

    @Autowired JdbcTemplate jdbc;

    @Test
    void anOwnerWithOtherCaregiversMustHandOverFirst() throws Exception {
        Account owner = registerCaregiver("Chi Hoa");
        Account member = registerCaregiver("Anh Nam");
        Long groupId = readId(body(mvc.perform(json(as(owner, post("/api/groups")), "{\"name\":\"Nhà\"}")).andReturn()), "$.id");
        String invite = read(body(mvc.perform(as(owner, post("/api/groups/" + groupId + "/invites"))).andReturn()), "$.code");
        mvc.perform(json(as(member, post("/api/invites/accept")), "{\"code\":\"" + invite + "\"}")).andExpect(status().isOk());

        mvc.perform(as(owner, delete("/api/me"))).andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("confirm_required"));
        mvc.perform(as(owner, delete("/api/me?confirm=true"))).andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("transfer_required"));
        // A member can always delete: they just leave.
        mvc.perform(as(member, delete("/api/me?confirm=true"))).andExpect(status().isNoContent());
        mvc.perform(as(member, get("/api/me"))).andExpect(status().isUnauthorized());
        mvc.perform(as(owner, get("/api/groups/" + groupId))).andExpect(jsonPath("$.members.length()").value(1));
    }

    @Test
    void theLastCaregiverTakesTheGroupAndTheEldersPersonalDataWithThem() throws Exception {
        Account owner = registerCaregiver("Chi Hoa");
        String email = jdbc.queryForObject("SELECT email FROM users WHERE id = ?", String.class, owner.id());
        Long groupId = readId(body(mvc.perform(json(as(owner, post("/api/groups")), "{\"name\":\"Nhà\"}")).andReturn()), "$.id");
        Long elderId = readId(body(mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/elders")),
                "{\"callName\":\"Bà Lan\",\"phone\":\"0911111111\",\"birthYear\":1948}")).andReturn()), "$.userId");
        mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/elders/" + elderId + "/medications")),
                "{\"name\":\"Amlodipin\",\"note\":\"uống sau ăn\",\"times\":[\"08:00\"]}")).andExpect(status().isCreated());
        jdbc.update("INSERT INTO notification_outbox (dedupe_key, user_id, kind, group_id, title, body, urgent, status, created_at) "
                + "VALUES (?, ?, 'ALERT', ?, 'Bà Lan chưa xác nhận uống thuốc', 'Amlodipin', true, 'SENT', now())",
                "test-" + groupId, owner.id(), groupId);

        mvc.perform(as(owner, delete("/api/me?confirm=true"))).andExpect(status().isNoContent());

        // Nothing left that says who took which medicine.
        assertThat(jdbc.queryForObject("SELECT birth_year FROM elder_profiles WHERE user_id = ?", Short.class, elderId)).isNull();
        assertThat(jdbc.queryForList("SELECT name || coalesce(note, '') FROM medications WHERE group_id = ?", String.class, groupId))
                .containsOnly("Thuốc đã xóa");
        assertThat(jdbc.queryForObject("SELECT count(*) FROM notification_outbox WHERE group_id = ?", Integer.class, groupId)).isZero();
        assertThat(jdbc.queryForObject("SELECT count(*) FROM audit_logs WHERE group_id = ? AND changes IS NOT NULL",
                Integer.class, groupId)).isZero();

        Map<String, Object> me = jdbc.queryForMap("SELECT email, password_hash, disabled FROM users WHERE id = ?", owner.id());
        assertThat(me.get("email")).isNull();
        assertThat(me.get("password_hash")).isNull();
        assertThat(me.get("disabled")).isEqualTo(true);
        Map<String, Object> elder = jdbc.queryForMap("SELECT phone, call_name FROM elder_profiles WHERE user_id = ?", elderId);
        assertThat(elder.get("phone")).isNull();
        assertThat(elder.get("call_name")).isEqualTo("Người dùng đã xóa");
        assertThat(jdbc.queryForObject("SELECT count(*) FROM medications WHERE group_id = ? AND active", Integer.class, groupId)).isZero();
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"" + email + "\",\"password\":\"matkhau123\"}")).andExpect(status().isUnauthorized());
        // The email is free for a new account.
        mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"" + email + "\",\"password\":\"matkhau123\",\"displayName\":\"Mới\"}"))
                .andExpect(status().isCreated());
    }

    @Test
    void anOwnerCanRemoveOneParentAndKeepTheOther() throws Exception {
        Account owner = registerCaregiver("Chi Hoa");
        Long groupId = readId(body(mvc.perform(json(as(owner, post("/api/groups")), "{\"name\":\"Nhà\"}")).andReturn()), "$.id");
        Long father = readId(body(mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/elders")),
                "{\"callName\":\"Ông Ba\"}")).andReturn()), "$.userId");
        Long mother = readId(body(mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/elders")),
                "{\"callName\":\"Bà Lan\"}")).andReturn()), "$.userId");
        mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/elders/" + father + "/medications")),
                "{\"name\":\"Metformin\",\"times\":[\"08:00\"]}")).andExpect(status().isCreated());
        Account fatherPhone = pairElder(pairingCode(owner, groupId, father));

        mvc.perform(as(owner, delete("/api/groups/" + groupId + "/elders/" + father))).andExpect(status().isNoContent());

        mvc.perform(as(owner, get("/api/groups/" + groupId))).andExpect(jsonPath("$.members.length()").value(2)); // owner + mother
        assertThat(jdbc.queryForObject("SELECT call_name FROM elder_profiles WHERE user_id = ?", String.class, mother)).isEqualTo("Bà Lan");
        assertThat(jdbc.queryForObject("SELECT call_name FROM elder_profiles WHERE user_id = ?", String.class, father))
                .isEqualTo("Người dùng đã xóa");
        assertThat(jdbc.queryForList("SELECT name FROM medications WHERE elder_user_id = ?", String.class, father))
                .containsOnly("Thuốc đã xóa");
        mvc.perform(post("/api/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"" + fatherPhone.refreshToken() + "\"}")).andExpect(status().isUnauthorized());
        // Someone outside the family cannot, and does not even learn that it exists.
        Account stranger = registerCaregiver("Người lạ");
        mvc.perform(as(stranger, delete("/api/groups/" + groupId + "/elders/" + mother))).andExpect(status().isNotFound());
    }
}
