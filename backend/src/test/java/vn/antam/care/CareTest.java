package vn.antam.care;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import vn.antam.IntegrationTest;

/** Phase 5 DoD: every answer raises the right alert, offline resends never duplicate, "not taken" is not taken. */
class CareTest extends IntegrationTest {

    @Autowired
    JdbcTemplate jdbc;

    Account owner;
    Account member;
    Account outsider;
    Account elder;
    Long groupId;
    Long elderId;
    Long amlodipin;
    Long metformin;
    String today;

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
        String meds = "/api/groups/" + groupId + "/elders/" + elderId + "/medications";
        amlodipin = readId(body(mvc.perform(json(as(owner, post(meds)), "{\"name\":\"Amlodipin\",\"dosage\":\"1 viên\",\"times\":[\"08:00\"]}"))
                .andExpect(status().isCreated()).andReturn()), "$.id");
        metformin = readId(body(mvc.perform(json(as(owner, post(meds)), "{\"name\":\"Metformin\",\"times\":[\"08:00\"]}"))
                .andExpect(status().isCreated()).andReturn()), "$.id");
        today = LocalDate.now(ZoneId.of("Asia/Ho_Chi_Minh")).toString();
    }

    private String report(UUID id, String status, String check, String issue, Long... meds) {
        return """
                {"clientEventId":"%s","scheduledDate":"%s","scheduledTime":"08:00","medicationIds":%s,
                 "status":"%s","source":"BUTTON","checkResult":"%s","issue":%s}
                """.formatted(id, today, List.of(meds), status, check, issue == null ? "null" : "\"" + issue + "\"");
    }

    private String openAlerts() throws Exception {
        return body(mvc.perform(as(owner, get("/api/groups/" + groupId + "/alerts"))).andExpect(status().isOk()).andReturn());
    }

    @Test
    void takenWithNoProblemLogsBothMedicinesAndRaisesNoAlert() throws Exception {
        mvc.perform(json(as(elder, post("/api/me/dose-reports")), report(UUID.randomUUID(), "TAKEN", "NONE", null, amlodipin, metformin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.doseLogIds.length()").value(2))
                .andExpect(jsonPath("$.alertId").doesNotExist())
                .andExpect(jsonPath("$.duplicate").value(false));
        assertThat((List<?>) read(openAlerts(), "$")).isEmpty();
        mvc.perform(as(member, get("/api/groups/" + groupId + "/elders/" + elderId + "/doses").param("date", today)))
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].status").value("TAKEN"))
                .andExpect(jsonPath("$[0].checkResult").value("NONE"));
        // The elder's phone sees its own logs with the schedule (e.g. after reinstalling).
        mvc.perform(as(elder, get("/api/me/schedule"))).andExpect(jsonPath("$.recentDoses.length()").value(2));
    }

    @ParameterizedTest(name = "{0} raises {0}")
    @CsvSource({"LOST_MEDICINE", "OUT_OF_MEDICINE", "UNSURE_PILL", "UNWELL", "OTHER_ISSUE"})
    void eachProblemRaisesItsOwnAlert(String issue) throws Exception {
        String result = body(mvc.perform(json(as(elder, post("/api/me/dose-reports")),
                report(UUID.randomUUID(), "TAKEN", "ISSUE", issue, amlodipin))).andExpect(status().isOk()).andReturn());
        assertThat((Object) read(result, "$.alertId")).isNotNull();
        String alerts = openAlerts();
        assertThat((List<?>) read(alerts, "$")).hasSize(1);
        assertThat((String) read(alerts, "$[0].kind")).isEqualTo(issue);
        assertThat((String) read(alerts, "$[0].elderName")).isEqualTo("Bà Lan");
        assertThat((String) read(alerts, "$[0].medicationNames")).isEqualTo("Amlodipin");
        assertThat((String) read(alerts, "$[0].scheduledTime")).isEqualTo("08:00");
    }

    @Test
    void noAnswerKeepsTheDoseTakenAndRaisesNoAlert() throws Exception {
        mvc.perform(json(as(elder, post("/api/me/dose-reports")), report(UUID.randomUUID(), "TAKEN", "NO_RESPONSE", null, amlodipin)))
                .andExpect(status().isOk());
        assertThat((List<?>) read(openAlerts(), "$")).isEmpty();
        assertThat(jdbc.queryForObject("SELECT status || '/' || check_result FROM dose_logs WHERE medication_id = ?", String.class, amlodipin))
                .isEqualTo("TAKEN/NO_RESPONSE");
    }

    @Test
    void notTakenIsRecordedAsNotTakenWithItsReason() throws Exception {
        mvc.perform(json(as(elder, post("/api/me/dose-reports")),
                report(UUID.randomUUID(), "NOT_TAKEN", "ISSUE", "OUT_OF_MEDICINE", amlodipin))).andExpect(status().isOk());
        assertThat(jdbc.queryForObject("SELECT status FROM dose_logs WHERE medication_id = ?", String.class, amlodipin)).isEqualTo("NOT_TAKEN");
        assertThat((String) read(openAlerts(), "$[0].kind")).isEqualTo("OUT_OF_MEDICINE");
    }

    @Test
    void resendingFromTheOfflineQueueNeverDuplicates() throws Exception {
        UUID id = UUID.randomUUID();
        String body = report(id, "TAKEN", "ISSUE", "LOST_MEDICINE", amlodipin, metformin);
        String first = body(mvc.perform(json(as(elder, post("/api/me/dose-reports")), body)).andExpect(status().isOk()).andReturn());
        String again = body(mvc.perform(json(as(elder, post("/api/me/dose-reports")), body)).andExpect(status().isOk()).andReturn());
        assertThat((Boolean) read(again, "$.duplicate")).isTrue();
        assertThat((Object) read(again, "$.alertId")).isEqualTo(read(first, "$.alertId"));
        assertThat(jdbc.queryForObject("SELECT count(*) FROM dose_logs WHERE elder_user_id = ?", Integer.class, elderId)).isEqualTo(2);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM alerts WHERE elder_user_id = ?", Integer.class, elderId)).isEqualTo(1);
    }

    @Test
    void parallelCopiesOfTheSameReportStillMakeOneRecord() throws Exception {
        String body = report(UUID.randomUUID(), "TAKEN", "ISSUE", "UNWELL", amlodipin);
        Callable<Integer> send = () -> mvc.perform(json(as(elder, post("/api/me/dose-reports")), body)).andReturn().getResponse().getStatus();
        var pool = Executors.newFixedThreadPool(4);
        List<Future<Integer>> results = pool.invokeAll(List.of(send, send, send, send));
        pool.shutdown();
        for (Future<Integer> f : results) assertThat(f.get()).isEqualTo(200);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM dose_logs WHERE elder_user_id = ?", Integer.class, elderId)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM alerts WHERE elder_user_id = ?", Integer.class, elderId)).isEqualTo(1);
    }

    @Test
    void aSecondReportForTheSameDoseKeepsTheFirstAnswer() throws Exception {
        mvc.perform(json(as(elder, post("/api/me/dose-reports")), report(UUID.randomUUID(), "TAKEN", "NONE", null, amlodipin)));
        mvc.perform(json(as(elder, post("/api/me/dose-reports")), report(UUID.randomUUID(), "NOT_TAKEN", "NO_RESPONSE", null, amlodipin)))
                .andExpect(status().isOk());
        assertThat(jdbc.queryForObject("SELECT string_agg(status, ',') FROM dose_logs WHERE medication_id = ?", String.class, amlodipin))
                .isEqualTo("TAKEN");
    }

    @Test
    void invalidReportsAreRejected() throws Exception {
        mvc.perform(json(as(elder, post("/api/me/dose-reports")), report(UUID.randomUUID(), "TAKEN", "ISSUE", null, amlodipin)))
                .andExpect(status().isBadRequest());
        mvc.perform(json(as(elder, post("/api/me/dose-reports")), report(UUID.randomUUID(), "TAKEN", "NONE", "UNWELL", amlodipin)))
                .andExpect(status().isBadRequest());
        mvc.perform(json(as(elder, post("/api/me/dose-reports")), report(UUID.randomUUID(), "SKIPPED", "NONE", null, amlodipin)))
                .andExpect(status().isBadRequest());
        mvc.perform(json(as(elder, post("/api/me/dose-reports")), report(UUID.randomUUID(), "TAKEN", "ISSUE", "NOT_CONFIRMED", amlodipin)))
                .andExpect(status().isBadRequest());
        mvc.perform(json(as(elder, post("/api/me/dose-reports")), report(UUID.randomUUID(), "MAYBE", "NONE", null, amlodipin)))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("validation"));
    }

    @Test
    void onlyTheEldersOwnPhoneReportsAndOnlyForItsOwnMedicines() throws Exception {
        String body = report(UUID.randomUUID(), "TAKEN", "NONE", null, amlodipin);
        mvc.perform(json(as(owner, post("/api/me/dose-reports")), body)).andExpect(status().isForbidden());
        mvc.perform(json(as(member, post("/api/me/alerts")), "{\"clientEventId\":\"" + UUID.randomUUID() + "\",\"kind\":\"UNWELL\"}"))
                .andExpect(status().isForbidden());
        // Another family's elder cannot log this elder's medicine.
        Account other = registerCaregiver("Chu Ba");
        Long g2 = readId(body(mvc.perform(json(as(other, post("/api/groups")), "{\"name\":\"Nhà ông Ba\"}")).andReturn()), "$.id");
        Long e2 = readId(body(mvc.perform(json(as(other, post("/api/groups/" + g2 + "/elders")), "{\"callName\":\"Ông Ba\"}")).andReturn()), "$.userId");
        String c2 = read(body(mvc.perform(as(other, post("/api/groups/" + g2 + "/elders/" + e2 + "/pairing-code"))).andReturn()), "$.code");
        String t2 = read(body(mvc.perform(json(post("/api/auth/elder-pair"), "{\"code\":\"" + c2 + "\",\"deviceName\":\"T\"}")).andReturn()), "$.accessToken");
        mvc.perform(post("/api/me/dose-reports").header("Authorization", "Bearer " + t2)
                        .contentType("application/json").content(report(UUID.randomUUID(), "TAKEN", "NONE", null, amlodipin)))
                .andExpect(status().isNotFound());
    }

    @Test
    void unwellFromTheHomeScreenAndResolvingAlerts() throws Exception {
        UUID id = UUID.randomUUID();
        String alert = "{\"clientEventId\":\"" + id + "\",\"kind\":\"UNWELL\"}";
        mvc.perform(json(as(elder, post("/api/me/alerts")), alert)).andExpect(status().isOk()).andExpect(jsonPath("$.kind").value("UNWELL"));
        mvc.perform(json(as(elder, post("/api/me/alerts")), alert)).andExpect(status().isOk());
        Long alertId = readId(openAlerts(), "$[0].id");
        assertThat((List<?>) read(openAlerts(), "$")).hasSize(1);

        // Elders and outsiders cannot see or resolve alerts.
        mvc.perform(as(elder, get("/api/groups/" + groupId + "/alerts"))).andExpect(status().isForbidden());
        mvc.perform(as(outsider, get("/api/groups/" + groupId + "/alerts"))).andExpect(status().isNotFound());
        mvc.perform(as(elder, post("/api/groups/" + groupId + "/alerts/" + alertId + "/resolve"))).andExpect(status().isForbidden());
        mvc.perform(as(outsider, post("/api/groups/" + groupId + "/alerts/" + alertId + "/resolve"))).andExpect(status().isNotFound());

        // Any caregiver resolves; the first resolver is kept and everyone sees it.
        mvc.perform(as(member, post("/api/groups/" + groupId + "/alerts/" + alertId + "/resolve")))
                .andExpect(status().isOk()).andExpect(jsonPath("$.resolvedByName").value("Anh Nam"));
        mvc.perform(as(owner, post("/api/groups/" + groupId + "/alerts/" + alertId + "/resolve")))
                .andExpect(jsonPath("$.resolvedByName").value("Anh Nam"));
        assertThat((List<?>) read(openAlerts(), "$")).isEmpty();
        mvc.perform(as(owner, get("/api/groups/" + groupId + "/alerts").param("openOnly", "false")))
                .andExpect(jsonPath("$.length()").value(1)).andExpect(jsonPath("$[0].resolvedAt").exists());
    }
}
