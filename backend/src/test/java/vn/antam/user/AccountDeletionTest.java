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
                "{\"callName\":\"Bà Lan\",\"phone\":\"0911111111\"}")).andReturn()), "$.userId");
        mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/elders/" + elderId + "/medications")),
                "{\"name\":\"Amlodipin\",\"times\":[\"08:00\"]}")).andExpect(status().isCreated());

        mvc.perform(as(owner, delete("/api/me?confirm=true"))).andExpect(status().isNoContent());

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
}
