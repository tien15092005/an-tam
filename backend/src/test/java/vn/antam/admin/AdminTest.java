package vn.antam.admin;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;

import vn.antam.IntegrationTest;
import vn.antam.user.User;
import vn.antam.user.UserRepository;

/** Phase 10 DoD: the admin sees totals only (no medicines, photos, chat), and locking ends the session. */
class AdminTest extends IntegrationTest {

    @Autowired UserRepository users;
    @Autowired PasswordEncoder encoder;

    Account admin;
    Account owner;
    Long groupId;
    Long elderId;
    Long medId;

    @BeforeEach
    void setUp() throws Exception {
        String email = "admin." + UUID.randomUUID().toString().substring(0, 8) + "@test.vn";
        users.save(User.admin(email, encoder.encode("matkhau-admin-123"), java.time.Instant.now()));
        String login = body(mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"" + email + "\",\"password\":\"matkhau-admin-123\"}")).andExpect(status().isOk()).andReturn());
        String token = read(login, "$.accessToken");
        admin = new Account(meId(token), token, read(login, "$.refreshToken"));

        owner = registerCaregiver("Chi Hoa");
        groupId = readId(body(mvc.perform(json(as(owner, post("/api/groups")), "{\"name\":\"Nhà\"}")).andReturn()), "$.id");
        elderId = readId(body(mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/elders")), "{\"callName\":\"Bà Lan\"}"))
                .andReturn()), "$.userId");
        medId = readId(body(mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/elders/" + elderId + "/medications")),
                "{\"name\":\"Amlodipin\",\"times\":[\"08:00\"]}")).andReturn()), "$.id");
        mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/chat/messages")),
                "{\"clientMessageId\":\"" + UUID.randomUUID() + "\",\"body\":\"bí mật gia đình\"}")).andExpect(status().isOk());
    }

    @Test
    void theAdminSeesTotalsButNoMedicinesPhotosChatOrDoses() throws Exception {
        mvc.perform(as(admin, get("/api/admin/stats"))).andExpect(status().isOk())
                .andExpect(jsonPath("$.usersByType.CAREGIVER").isNumber())
                .andExpect(jsonPath("$.groups").isNumber())
                .andExpect(jsonPath("$.openAlerts").isNumber());
        String base = "/api/groups/" + groupId;
        String today = LocalDate.now(ZoneId.of("Asia/Ho_Chi_Minh")).toString();
        for (String path : new String[] {
                base, base + "/elders/" + elderId + "/medications", base + "/medication-images/1", base + "/chat/messages",
                base + "/alerts", base + "/elders/" + elderId + "/day?date=" + today,
                base + "/elders/" + elderId + "/doses?date=" + today, base + "/elders/" + elderId + "/exercises"}) {
            mvc.perform(as(admin, get(path))).andExpect(status().isNotFound());
        }
        // The search shows accounts, never health data.
        mvc.perform(as(admin, get("/api/admin/users?q=Chi Hoa"))).andExpect(status().isOk())
                .andExpect(jsonPath("$[0].displayName").value("Chi Hoa"))
                .andExpect(jsonPath("$[0].groups").value(1))
                .andExpect(jsonPath("$[0].medications").doesNotExist());
    }

    @Test
    void onlyTheAdminUsesAdminEndpoints() throws Exception {
        mvc.perform(as(owner, get("/api/admin/stats"))).andExpect(status().isForbidden());
        mvc.perform(as(owner, post("/api/admin/users/" + admin.id() + "/disable"))).andExpect(status().isForbidden());
        mvc.perform(get("/api/admin/stats")).andExpect(status().isUnauthorized());
    }

    @Test
    void lockingAnAccountEndsItsSessionAtOnceAndUnlockingLetsItSignInAgain() throws Exception {
        mvc.perform(as(owner, get("/api/me"))).andExpect(status().isOk());
        mvc.perform(as(admin, post("/api/admin/users/" + owner.id() + "/disable"))).andExpect(status().isNoContent());
        // The access token was still in date: refused anyway.
        mvc.perform(as(owner, get("/api/me"))).andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("account_disabled"));
        mvc.perform(post("/api/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"" + owner.refreshToken() + "\"}")).andExpect(status().is4xxClientError());
        mvc.perform(as(admin, post("/api/admin/users/" + admin.id() + "/disable"))).andExpect(status().isBadRequest());

        mvc.perform(as(admin, post("/api/admin/users/" + owner.id() + "/enable"))).andExpect(status().isNoContent());
        String email = users.findById(owner.id()).orElseThrow().getEmail();
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"" + email + "\",\"password\":\"matkhau123\"}")).andExpect(status().isOk());
    }
}
