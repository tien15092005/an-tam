package vn.antam.care;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;

import vn.antam.IntegrationTest;
import vn.antam.notification.DeviceRepository;
import vn.antam.notification.OutboxDispatcher;
import vn.antam.notification.OutboxRepository;
import vn.antam.notification.PushSender;

/**
 * Phase 6 DoD: every caregiver gets each report once, marking for the elder stops the alarm, NOT_CONFIRMED
 * is raised once per dose time and caught up after downtime, and the outbox measures its delay.
 */
class TodayTest extends IntegrationTest {

    static final ZoneId VN = ZoneId.of("Asia/Ho_Chi_Minh");

    @Autowired JdbcTemplate jdbc;
    @Autowired DoseSweeper sweeper;
    @Autowired OutboxRepository outbox;
    @Autowired DeviceRepository devices;

    Account owner;
    Account member;
    Account outsider;
    Account elder;
    Long groupId;
    Long elderId;
    Long amlodipin;
    Long metformin;
    LocalDate yesterday;

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
        amlodipin = readId(body(mvc.perform(json(as(owner, post(meds)), "{\"name\":\"Amlodipin\",\"times\":[\"08:00\",\"12:00\"]}"))
                .andExpect(status().isCreated()).andReturn()), "$.id");
        metformin = readId(body(mvc.perform(json(as(owner, post(meds)), "{\"name\":\"Metformin\",\"times\":[\"08:00\"]}"))
                .andExpect(status().isCreated()).andReturn()), "$.id");
        // Both medicines have been taken for a few days, so yesterday's doses count.
        LocalDate today = LocalDate.now(VN);
        yesterday = today.minusDays(1);
        jdbc.update("UPDATE medications SET start_date = ?, created_at = ? WHERE id IN (?, ?)", yesterday,
                Timestamp.from(Instant.now().minusSeconds(4 * 86400)), amlodipin, metformin);
        jdbc.update("DELETE FROM notification_outbox WHERE user_id IN (?, ?, ?)", owner.id(), member.id(), elderId);
    }

    private String dayUrl(LocalDate d) {
        return "/api/groups/" + groupId + "/elders/" + elderId + "/day?date=" + d;
    }

    private String mark(UUID id, LocalDate date, String time, Long... meds) {
        return """
                {"clientEventId":"%s","scheduledDate":"%s","scheduledTime":"%s","medicationIds":%s}
                """.formatted(id, date, time, List.of(meds));
    }

    private String elderReport(UUID id, LocalDate date, String time, String status, String check, String issue, Long... meds) {
        return """
                {"clientEventId":"%s","scheduledDate":"%s","scheduledTime":"%s","medicationIds":%s,
                 "status":"%s","source":"BUTTON","checkResult":"%s","issue":%s}
                """.formatted(id, date, time, List.of(meds), status, check, issue == null ? "null" : "\"" + issue + "\"");
    }

    private List<Map<String, Object>> notifications(Long userId) {
        return jdbc.queryForList("SELECT kind, title, urgent, ref_id FROM notification_outbox WHERE user_id = ? ORDER BY id", userId);
    }

    private Instant at(LocalDate d, String hhmm) {
        return d.atTime(java.time.LocalTime.parse(hhmm)).atZone(VN).toInstant();
    }

    @Test
    void theDayShowsEveryDoseWithItsStatusAndWhoAnswered() throws Exception {
        mvc.perform(json(as(elder, post("/api/me/dose-reports")),
                        elderReport(UUID.randomUUID(), yesterday, "08:00", "TAKEN", "NONE", null, amlodipin, metformin)))
                .andExpect(status().isOk());
        mvc.perform(as(member, get(dayUrl(yesterday))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.callName").value("Bà Lan"))
                .andExpect(jsonPath("$.slots.length()").value(3))
                .andExpect(jsonPath("$.slots[0].scheduledTime").value("08:00"))
                .andExpect(jsonPath("$.slots[0].status").value("TAKEN"))
                .andExpect(jsonPath("$.slots[0].source").value("BUTTON"))
                .andExpect(jsonPath("$.slots[0].canUndo").value(false))
                .andExpect(jsonPath("$.slots[2].scheduledTime").value("12:00"))
                .andExpect(jsonPath("$.slots[2].status").value("MISSED"))
                .andExpect(jsonPath("$.slots[2].canMark").value(true))
                .andExpect(jsonPath("$.counts.taken").value(2))
                .andExpect(jsonPath("$.counts.missed").value(1));
        mvc.perform(as(owner, get(dayUrl(LocalDate.now(VN).plusDays(1)))))
                .andExpect(jsonPath("$.counts.upcoming").value(3))
                .andExpect(jsonPath("$.slots[0].canMark").value(false));
    }

    @Test
    void onlyCaregiversOfTheGroupSeeTheDayOrMark() throws Exception {
        mvc.perform(as(outsider, get(dayUrl(yesterday)))).andExpect(status().isNotFound());
        mvc.perform(as(elder, get(dayUrl(yesterday)))).andExpect(status().isForbidden());
        String url = "/api/groups/" + groupId + "/elders/" + elderId + "/doses";
        mvc.perform(json(as(outsider, post(url)), mark(UUID.randomUUID(), yesterday, "12:00", amlodipin))).andExpect(status().isNotFound());
        mvc.perform(json(as(elder, post(url)), mark(UUID.randomUUID(), yesterday, "12:00", amlodipin))).andExpect(status().isForbidden());
    }

    @Test
    void aMemberMarksForTheElderTheElderIsToldToStopAndOthersAreToldOnce() throws Exception {
        String url = "/api/groups/" + groupId + "/elders/" + elderId + "/doses";
        UUID id = UUID.randomUUID();
        mvc.perform(json(as(member, post(url)), mark(id, yesterday, "12:00", amlodipin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.doseLogIds.length()").value(1));
        // Resent (the caregiver's phone retried): nothing new.
        mvc.perform(json(as(member, post(url)), mark(id, yesterday, "12:00", amlodipin)))
                .andExpect(jsonPath("$.doseLogIds.length()").value(0))
                .andExpect(jsonPath("$.alreadyLogged.length()").value(1));

        assertThat(notifications(elderId)).extracting(n -> n.get("kind")).containsExactly("DOSE_MARKED");
        assertThat(notifications(elderId).getFirst().get("title")).isNull(); // data only: stop ringing, reload
        assertThat(notifications(owner.id())).hasSize(1);
        assertThat(notifications(owner.id()).getFirst().get("title")).isEqualTo("Anh Nam đã đánh dấu giúp Bà Lan");
        assertThat(notifications(member.id())).isEmpty(); // the one who marked is not told

        mvc.perform(as(owner, get(dayUrl(yesterday))))
                .andExpect(jsonPath("$.slots[2].status").value("TAKEN"))
                .andExpect(jsonPath("$.slots[2].source").value("CAREGIVER"))
                .andExpect(jsonPath("$.slots[2].loggedByName").value("Anh Nam"))
                .andExpect(jsonPath("$.slots[2].canUndo").value(true));

        // The elder answers later: first answer wins, the caregiver's mark stays.
        mvc.perform(json(as(elder, post("/api/me/dose-reports")),
                        elderReport(UUID.randomUUID(), yesterday, "12:00", "NOT_TAKEN", "NO_RESPONSE", null, amlodipin)))
                .andExpect(status().isOk());
        assertThat(jdbc.queryForObject("SELECT status FROM dose_logs WHERE medication_id = ? AND scheduled_date = ? AND scheduled_time = '12:00'",
                String.class, amlodipin, yesterday)).isEqualTo("TAKEN");
    }

    @Test
    void markingTheFutureOrSomethingNotScheduledIsRefused() throws Exception {
        String url = "/api/groups/" + groupId + "/elders/" + elderId + "/doses";
        mvc.perform(json(as(owner, post(url)), mark(UUID.randomUUID(), LocalDate.now(VN).plusDays(1), "08:00", amlodipin)))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("too_early"));
        mvc.perform(json(as(owner, post(url)), mark(UUID.randomUUID(), yesterday, "12:00", metformin)))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("not_scheduled"));
        mvc.perform(json(as(owner, post(url)), mark(UUID.randomUUID(), LocalDate.now(VN).minusDays(10), "08:00", amlodipin)))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("too_old"));
    }

    @Test
    void onlyACaregiversMarkCanBeUndone() throws Exception {
        String url = "/api/groups/" + groupId + "/elders/" + elderId + "/doses";
        Long marked = readId(body(mvc.perform(json(as(owner, post(url)), mark(UUID.randomUUID(), yesterday, "12:00", amlodipin)))
                .andReturn()), "$.doseLogIds[0]");
        Long eldersOwn = readId(body(mvc.perform(json(as(elder, post("/api/me/dose-reports")),
                elderReport(UUID.randomUUID(), yesterday, "08:00", "TAKEN", "NONE", null, metformin))).andReturn()), "$.doseLogIds[0]");

        mvc.perform(as(member, delete(url + "/" + eldersOwn))).andExpect(status().isForbidden());
        mvc.perform(as(outsider, delete(url + "/" + marked))).andExpect(status().isNotFound());
        mvc.perform(as(member, delete(url + "/" + marked))).andExpect(status().isNoContent());
        mvc.perform(as(owner, get(dayUrl(yesterday)))).andExpect(jsonPath("$.counts.missed").value(2));
        assertThat(jdbc.queryForObject("SELECT count(*) FROM audit_logs WHERE action = 'DOSE_UNMARKED' AND entity_id = ?",
                Integer.class, marked)).isEqualTo(1);
    }

    @Test
    void anUnansweredDoseRaisesOneNotConfirmedAlertAfterThirtyMinutes() throws Exception {
        // 08:30: the phone has rung 3 times (08:00, 08:10, 08:20) but it is only 30 minutes late, nothing yet.
        assertThat(sweeper.sweep(at(yesterday, "08:30")).stream().filter(this::mine).toList()).isEmpty();
        // 08:31: one alert for the 08:00 alarm (both medicines), told to every caregiver once.
        List<Long> first = sweeper.sweep(at(yesterday, "08:31")).stream().filter(this::mine).toList();
        assertThat(first).hasSize(1);
        assertThat(sweeper.sweep(at(yesterday, "09:30")).stream().filter(this::mine).toList()).isEmpty();
        Map<String, Object> alert = jdbc.queryForMap("SELECT kind, medication_names, scheduled_time FROM alerts WHERE id = ?", first.getFirst());
        assertThat(alert.get("kind")).isEqualTo("NOT_CONFIRMED");
        assertThat(alert.get("medication_names")).isEqualTo("Amlodipin, Metformin");
        assertThat(notifications(owner.id())).hasSize(1);
        assertThat(notifications(member.id())).hasSize(1);
        assertThat(notifications(owner.id()).getFirst().get("title")).isEqualTo("Bà Lan chưa xác nhận uống thuốc");
        assertThat(notifications(elderId)).isEmpty();

        // The elder answers late from the home screen: the alert closes itself and the report says it came late.
        mvc.perform(json(as(elder, post("/api/me/dose-reports")),
                        elderReport(UUID.randomUUID(), yesterday, "08:00", "TAKEN", "NONE", null, amlodipin, metformin)))
                .andExpect(status().isOk());
        assertThat(jdbc.queryForObject("SELECT resolved_by FROM alerts WHERE id = ?", Long.class, first.getFirst())).isEqualTo(elderId);
        assertThat(jdbc.queryForList("SELECT body FROM notification_outbox WHERE user_id = ? AND kind = 'DOSE_REPORT'", String.class,
                owner.id())).singleElement().asString().endsWith("· trả lời muộn");
    }

    @Test
    void aBrokenTimeZoneInOneFamilyDoesNotStopAlertsForOthers() throws Exception {
        // A row saved before time zones were validated (another family's parent).
        jdbc.update("UPDATE elder_profiles SET timezone = 'Asia/HoChiMinh' WHERE user_id <> ?", elderId);
        jdbc.update("UPDATE elder_profiles SET timezone = 'Not/AZone' WHERE user_id = (SELECT min(user_id) FROM elder_profiles "
                + "WHERE user_id <> ?)", elderId);
        assertThat(sweeper.sweep(at(yesterday, "08:31")).stream().filter(this::mine).toList()).hasSize(1);
    }

    @Test
    void afterTheLaptopWasOffTheSweepCatchesUpButDoesNotRaiseAnsweredDoses() throws Exception {
        mvc.perform(json(as(elder, post("/api/me/dose-reports")),
                        elderReport(UUID.randomUUID(), yesterday, "08:00", "TAKEN", "NONE", null, amlodipin, metformin)))
                .andExpect(status().isOk());
        // Backend back at 20:00 after being off all day: 12:00 is caught up, 08:00 was answered.
        List<Long> ids = sweeper.sweep(at(yesterday, "20:00")).stream().filter(this::mine).toList();
        assertThat(ids).hasSize(1);
        assertThat(jdbc.queryForObject("SELECT scheduled_time::text FROM alerts WHERE id = ?", String.class, ids.getFirst()))
                .isEqualTo("12:00:00");
        // A caregiver marks it: the alert closes with their name.
        mvc.perform(json(as(member, post("/api/groups/" + groupId + "/elders/" + elderId + "/doses")),
                mark(UUID.randomUUID(), yesterday, "12:00", amlodipin))).andExpect(status().isOk());
        assertThat(jdbc.queryForObject("SELECT resolved_by FROM alerts WHERE id = ?", Long.class, ids.getFirst())).isEqualTo(member.id());
    }

    @Test
    void anElderReportReachesEveryCaregiverExactlyOnceEvenWhenResent() throws Exception {
        UUID id = UUID.randomUUID();
        for (int i = 0; i < 3; i++) {
            mvc.perform(json(as(elder, post("/api/me/dose-reports")),
                            elderReport(id, yesterday, "08:00", "TAKEN", "ISSUE", "OUT_OF_MEDICINE", amlodipin, metformin)))
                    .andExpect(status().isOk());
        }
        for (Account a : List.of(owner, member)) {
            List<Map<String, Object>> n = notifications(a.id());
            assertThat(n).hasSize(1);
            assertThat(n.getFirst().get("kind")).isEqualTo("ALERT");
            assertThat(n.getFirst().get("title")).isEqualTo("Bà Lan báo hết thuốc");
            assertThat(n.getFirst().get("urgent")).isEqualTo(true);
        }
        // A plain "taken, no problem" is a normal (not urgent) report.
        mvc.perform(json(as(elder, post("/api/me/dose-reports")),
                elderReport(UUID.randomUUID(), yesterday, "12:00", "TAKEN", "NONE", null, amlodipin))).andExpect(status().isOk());
        assertThat(notifications(owner.id())).extracting(n -> n.get("kind")).containsExactly("ALERT", "DOSE_REPORT");
        assertThat(notifications(owner.id()).get(1).get("urgent")).isEqualTo(false);
    }

    @Test
    void changingTheScheduleTellsTheEldersPhoneToReload() throws Exception {
        mvc.perform(json(as(owner, put("/api/groups/" + groupId + "/medications/" + metformin)),
                "{\"name\":\"Metformin\",\"times\":[\"08:00\",\"20:00\"]}")).andExpect(status().isOk());
        assertThat(notifications(elderId)).extracting(n -> n.get("kind")).containsExactly("SCHEDULE_CHANGED");
    }

    @Test
    void theOutboxSendsToEveryRegisteredPhoneForgetsDeadOnesAndMeasuresDelay() throws Exception {
        mvc.perform(json(as(owner, put("/api/me/device")), "{\"fcmToken\":\"tok-owner-" + owner.id() + "\",\"platform\":\"ANDROID\"}"))
                .andExpect(status().isNoContent());
        mvc.perform(json(as(member, put("/api/me/device")), "{\"fcmToken\":\"dead-" + member.id() + "\"}"))
                .andExpect(status().isNoContent());
        mvc.perform(json(as(elder, post("/api/me/alerts")), "{\"clientEventId\":\"" + UUID.randomUUID() + "\",\"kind\":\"UNWELL\"}"))
                .andExpect(status().isOk());

        List<String> sentTo = new ArrayList<>();
        PushSender fake = new PushSender() {
            public boolean enabled() { return true; }
            public Result send(String token, String title, String body, Map<String, String> data, boolean urgent) {
                if (!token.endsWith(owner.id().toString()) && !token.endsWith(member.id().toString())) return Result.SENT;
                sentTo.add(token + "|" + title + "|" + data.get("kind") + "|" + urgent);
                return token.startsWith("dead") ? Result.INVALID_TOKEN : Result.SENT;
            }
        };
        SimpleMeterRegistry meters = new SimpleMeterRegistry();
        OutboxDispatcher dispatcher = new OutboxDispatcher(outbox, devices, fake, Clock.systemUTC(), meters);
        for (int i = 0; i < 200 && dispatcher.dispatch() > 0; i++) {
            // drain everything queued by all tests
        }
        assertThat(sentTo).containsExactlyInAnyOrder(
                "tok-owner-" + owner.id() + "|Bà Lan báo không khỏe|ALERT|true",
                "dead-" + member.id() + "|Bà Lan báo không khỏe|ALERT|true");
        assertThat(devices.findByFcmToken("dead-" + member.id())).isEmpty();
        assertThat(jdbc.queryForList("SELECT status FROM notification_outbox WHERE user_id = ?", String.class, owner.id()))
                .containsExactly("SENT");
        assertThat(jdbc.queryForList("SELECT status FROM notification_outbox WHERE user_id = ?", String.class, member.id()))
                .containsExactly("NO_DEVICE");
        assertThat(meters.timer("antam.notifications.latency").count()).isPositive();
    }

    private boolean mine(Long alertId) {
        return jdbc.queryForObject("SELECT elder_user_id FROM alerts WHERE id = ?", Long.class, alertId).equals(elderId);
    }
}
