package vn.antam.group;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

import vn.antam.IntegrationTest;

/**
 * The permission matrix of SKILL_AN_TAM.md §5, checked cell by cell against a real database:
 * owner, member, elder and outsider each try every group action.
 */
class GroupAuthorizationTest extends IntegrationTest {

    @org.springframework.beans.factory.annotation.Autowired
    org.springframework.jdbc.core.JdbcTemplate jdbc;

    Account owner;
    Account member;
    Account outsider;
    Account elder;
    Long groupId;
    Long elderId;

    @BeforeEach
    void family() throws Exception {
        owner = registerCaregiver("Chi Hoa");
        member = registerCaregiver("Anh Nam");
        outsider = registerCaregiver("Nguoi La");

        groupId = readId(body(mvc.perform(json(as(owner, post("/api/groups")), "{\"name\":\"Nhà bà Lan\"}"))
                .andExpect(status().isCreated()).andReturn()), "$.id");

        String invite = read(body(mvc.perform(as(owner, post("/api/groups/" + groupId + "/invites")))
                .andExpect(status().isCreated()).andReturn()), "$.code");
        mvc.perform(json(as(member, post("/api/invites/accept")), "{\"code\":\"" + invite + "\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.myRole").value("MEMBER"));

        elderId = readId(body(mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/elders")),
                "{\"callName\":\"Bà Lan\",\"birthYear\":1952}")).andExpect(status().isCreated()).andReturn()), "$.userId");
        elder = pairElder(pairingCode(owner, groupId, elderId));
    }

    @Test
    void everyMemberCanViewTheGroupButOutsidersCannotEvenSeeIt() throws Exception {
        for (Account a : List.of(owner, member, elder)) {
            mvc.perform(as(a, get("/api/groups/" + groupId))).andExpect(status().isOk())
                    .andExpect(jsonPath("$.members.length()").value(3));
        }
        mvc.perform(as(outsider, get("/api/groups/" + groupId))).andExpect(status().isNotFound());
        mvc.perform(get("/api/groups/" + groupId)).andExpect(status().isUnauthorized());
    }

    @Test
    void onlyTheOwnerManagesTheGroup() throws Exception {
        String elderBody = "{\"callName\":\"Ông Tư\"}";
        String transfer = "{\"userId\":" + member.id() + "}";
        for (Account a : List.of(member, elder)) {
            mvc.perform(json(as(a, post("/api/groups/" + groupId + "/elders")), elderBody)).andExpect(status().isForbidden());
            mvc.perform(json(as(a, patch("/api/groups/" + groupId + "/elders/" + elderId)), elderBody)).andExpect(status().isForbidden());
            mvc.perform(as(a, post("/api/groups/" + groupId + "/elders/" + elderId + "/pairing-code"))).andExpect(status().isForbidden());
            mvc.perform(as(a, post("/api/groups/" + groupId + "/invites"))).andExpect(status().isForbidden());
            mvc.perform(json(as(a, post("/api/groups/" + groupId + "/transfer-ownership")), transfer)).andExpect(status().isForbidden());
            mvc.perform(as(a, delete("/api/groups/" + groupId + "/members/" + member.id()))).andExpect(status().isForbidden());
            mvc.perform(json(as(a, patch("/api/groups/" + groupId)), "{\"name\":\"X\"}")).andExpect(status().isForbidden());
        }
        // Outsiders get 404 for owner actions too, so group ids cannot be probed.
        mvc.perform(as(outsider, post("/api/groups/" + groupId + "/invites"))).andExpect(status().isNotFound());
        mvc.perform(json(as(outsider, post("/api/groups/" + groupId + "/elders")), elderBody)).andExpect(status().isNotFound());
        // The owner can do all of it.
        mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/elders")), elderBody)).andExpect(status().isCreated());
        mvc.perform(json(as(owner, patch("/api/groups/" + groupId)), "{\"name\":\"Nhà ông bà\"}")).andExpect(status().isNoContent());
    }

    @Test
    void eldersCannotCreateOrJoinGroupsOrLeave() throws Exception {
        mvc.perform(json(as(elder, post("/api/groups")), "{\"name\":\"X\"}")).andExpect(status().isForbidden());
        String invite = read(body(mvc.perform(as(owner, post("/api/groups/" + groupId + "/invites"))).andReturn()), "$.code");
        mvc.perform(json(as(elder, post("/api/invites/accept")), "{\"code\":\"" + invite + "\"}")).andExpect(status().isForbidden());
        mvc.perform(as(elder, post("/api/groups/" + groupId + "/leave"))).andExpect(status().isForbidden());
        mvc.perform(as(elder, get("/api/me"))).andExpect(jsonPath("$.accountType").value("ELDER"))
                .andExpect(jsonPath("$.groups[0].myRole").value("ELDER"));
    }

    @Test
    void aCaregiverCanBeInSeveralGroupsAndSwitchBetweenThem() throws Exception {
        mvc.perform(json(as(member, post("/api/groups")), "{\"name\":\"Nhà ông bà ngoại\"}")).andExpect(status().isCreated());
        mvc.perform(as(member, get("/api/groups"))).andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[?(@.myRole == 'OWNER')]").exists())
                .andExpect(jsonPath("$[?(@.myRole == 'MEMBER')]").exists());
    }

    @Test
    void inviteCodesWorkOnceAndAreCaseInsensitive() throws Exception {
        String code = read(body(mvc.perform(as(owner, post("/api/groups/" + groupId + "/invites"))).andReturn()), "$.code");
        Account second = registerCaregiver("Em Ut");
        mvc.perform(json(as(second, post("/api/invites/accept")), "{\"code\":\"" + code.toLowerCase() + "\"}")).andExpect(status().isOk());
        Account third = registerCaregiver("Chau");
        mvc.perform(json(as(third, post("/api/invites/accept")), "{\"code\":\"" + code + "\"}"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("invalid_code"));
        mvc.perform(json(as(member, post("/api/invites/accept")), "{\"code\":\"" + code + "\"}")).andExpect(status().isBadRequest());
    }

    @Test
    void transferringOwnershipMovesTheRights() throws Exception {
        mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/transfer-ownership")), "{\"userId\":" + elderId + "}"))
                .andExpect(status().isBadRequest());
        mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/transfer-ownership")), "{\"userId\":" + member.id() + "}"))
                .andExpect(status().isNoContent());
        mvc.perform(as(owner, post("/api/groups/" + groupId + "/invites"))).andExpect(status().isForbidden());
        mvc.perform(as(member, post("/api/groups/" + groupId + "/invites"))).andExpect(status().isCreated());
        mvc.perform(as(member, get("/api/groups/" + groupId))).andExpect(jsonPath("$.myRole").value("OWNER"));
    }

    @Test
    void ownerMustHandOverBeforeLeavingAndTheLastCaregiverDeletesTheGroup() throws Exception {
        mvc.perform(as(owner, post("/api/groups/" + groupId + "/leave")))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("transfer_required"));
        mvc.perform(as(member, post("/api/groups/" + groupId + "/leave"))).andExpect(status().isNoContent());
        mvc.perform(as(member, get("/api/groups/" + groupId))).andExpect(status().isNotFound());

        mvc.perform(as(owner, post("/api/groups/" + groupId + "/leave")))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("confirm_delete_required"));
        mvc.perform(as(owner, post("/api/groups/" + groupId + "/leave").param("confirmDelete", "true"))).andExpect(status().isNoContent());
        mvc.perform(as(owner, get("/api/groups/" + groupId))).andExpect(status().isNotFound());
        // The elder's phone is signed out with the group gone.
        refresh(elder.refreshToken()).andExpect(status().isUnauthorized());
    }

    @Test
    void ownerCanRemoveMembersButNotElders() throws Exception {
        mvc.perform(as(owner, delete("/api/groups/" + groupId + "/members/" + elderId))).andExpect(status().isBadRequest());
        mvc.perform(as(owner, delete("/api/groups/" + groupId + "/members/" + member.id()))).andExpect(status().isNoContent());
        mvc.perform(as(member, get("/api/groups/" + groupId))).andExpect(status().isNotFound());
    }

    @Test
    void pairingCodesAreSingleUseAndANewPhoneSignsOutTheOldOne() throws Exception {
        String code = pairingCode(owner, groupId, elderId);
        Account newPhone = pairElder(code);
        mvc.perform(json(post("/api/auth/elder-pair"), "{\"code\":\"" + code + "\"}"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("invalid_code"));
        refresh(elder.refreshToken()).andExpect(status().isUnauthorized());
        refresh(newPhone.refreshToken()).andExpect(status().isOk());
    }

    @Test
    void creatingANewPairingCodeCancelsTheOldOne() throws Exception {
        String first = pairingCode(owner, groupId, elderId);
        pairingCode(owner, groupId, elderId);
        mvc.perform(json(post("/api/auth/elder-pair"), "{\"code\":\"" + first + "\"}")).andExpect(status().isBadRequest());
    }

    @Test
    void refreshTokensRotateAndReplayRevokesEverySession() throws Exception {
        String second = read(body(refresh(owner.refreshToken()).andExpect(status().isOk()).andReturn()), "$.refreshToken");
        String third = read(body(refresh(second).andExpect(status().isOk()).andReturn()), "$.refreshToken");
        refresh(owner.refreshToken()).andExpect(status().isUnauthorized()); // replay after the next token was used
        refresh(third).andExpect(status().isUnauthorized());                 // so every session is revoked
    }

    @Test
    void aRefreshWhoseReplyWasLostCanBeSentAgainWithoutSigningTheElderOut() throws Exception {
        // The reply carrying the second token never reached the phone (bad network), so it sends the first again.
        String lost = read(body(refresh(elder.refreshToken()).andExpect(status().isOk()).andReturn()), "$.refreshToken");
        String retried = read(body(refresh(elder.refreshToken()).andExpect(status().isOk()).andReturn()), "$.refreshToken");
        refresh(lost).andExpect(status().isUnauthorized());     // the reply nobody received is dropped
        refresh(retried).andExpect(status().isOk());            // the phone carries on
    }

    @Test
    void aLateRetryOfAnOldRefreshTokenIsTreatedAsStolen() throws Exception {
        String second = read(body(refresh(elder.refreshToken()).andExpect(status().isOk()).andReturn()), "$.refreshToken");
        jdbc.update("UPDATE refresh_tokens SET rotated_at = rotated_at - interval '10 minutes' WHERE user_id = ? "
                + "AND rotated_at IS NOT NULL", elderId);
        refresh(elder.refreshToken()).andExpect(status().isUnauthorized());
        refresh(second).andExpect(status().isUnauthorized());
    }

    @Test
    void anElderWithAnUnknownTimeZoneIsRejected() throws Exception {
        mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/elders")),
                        "{\"callName\":\"Ông Ba\",\"timezone\":\"Asia/HoChiMinh\"}"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("invalid_timezone"));
    }

    @Test
    void guessingPairingCodesIsStoppedAfterTenTries() throws Exception {
        clearAttemptLimits(); // setup already paired one phone from this address
        for (int i = 0; i < 10; i++) {
            mvc.perform(json(post("/api/auth/elder-pair"), "{\"code\":\"00000" + i + "\"}")).andExpect(status().isBadRequest());
        }
        mvc.perform(json(post("/api/auth/elder-pair"), "{\"code\":\"123456\"}"))
                .andExpect(status().isTooManyRequests()).andExpect(jsonPath("$.code").value("too_many_attempts"));
    }

    @Test
    void anOldPhoneSigningInAgainDoesNotSignOutTheNewOne() throws Exception {
        Account newPhone = pairElder(pairingCode(owner, groupId, elderId));
        refresh(elder.refreshToken()).andExpect(status().isUnauthorized());
        refresh(newPhone.refreshToken()).andExpect(status().isOk());
    }

    @Test
    void loginChecksThePassword() throws Exception {
        String email = read(body(mvc.perform(as(owner, get("/api/me"))).andReturn()), "$.email");
        mvc.perform(json(post("/api/auth/login"), "{\"email\":\"" + email + "\",\"password\":\"sai-mat-khau\"}"))
                .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.code").value("bad_credentials"));
        mvc.perform(json(post("/api/auth/login"), "{\"email\":\"" + email.toUpperCase() + "\",\"password\":\"matkhau123\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.accessToken").exists());
    }

    @Test
    void registeringTheSameEmailTwiceIsRejected() throws Exception {
        String email = read(body(mvc.perform(as(owner, get("/api/me"))).andReturn()), "$.email");
        mvc.perform(json(post("/api/auth/register"),
                        "{\"email\":\"" + email + "\",\"password\":\"matkhau123\",\"displayName\":\"Trung\"}"))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("email_taken"));
    }

    private String pairingCode(Account by, Long group, Long elderUser) throws Exception {
        String code = read(body(mvc.perform(as(by, post("/api/groups/" + group + "/elders/" + elderUser + "/pairing-code")))
                .andExpect(status().isCreated()).andReturn()), "$.code");
        assertThat(code).matches("\\d{6}");
        return code;
    }

    private Account pairElder(String code) throws Exception {
        String json = body(mvc.perform(json(post("/api/auth/elder-pair"), "{\"code\":\"" + code + "\",\"deviceName\":\"Test\"}"))
                .andExpect(status().isOk()).andReturn());
        String token = read(json, "$.accessToken");
        return new Account(meId(token), token, read(json, "$.refreshToken"));
    }

    private org.springframework.test.web.servlet.ResultActions refresh(String refreshToken) throws Exception {
        return mvc.perform(post("/api/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"" + refreshToken + "\"}"));
    }
}
