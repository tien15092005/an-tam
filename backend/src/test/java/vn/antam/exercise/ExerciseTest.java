package vn.antam.exercise;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.sql.Timestamp;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.TemporalAdjusters;
import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import vn.antam.IntegrationTest;

/** Phase 7 DoD: calendar dots are right, a Mon-Wed-Fri exercise is due on exactly those days, members only view. */
class ExerciseTest extends IntegrationTest {

    static final ZoneId VN = ZoneId.of("Asia/Ho_Chi_Minh");

    @Autowired JdbcTemplate jdbc;

    Account owner;
    Account member;
    Account outsider;
    Account elder;
    Long groupId;
    Long elderId;
    String base;

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
        base = "/api/groups/" + groupId + "/elders/" + elderId;
    }

    private Long createExercise(String json) throws Exception {
        return readId(body(mvc.perform(json(as(owner, post(base + "/exercises")), json)).andExpect(status().isCreated()).andReturn()), "$.id");
    }

    private String calendar(LocalDate from, LocalDate to) throws Exception {
        return body(mvc.perform(as(member, get(base + "/calendar?from=" + from + "&to=" + to))).andExpect(status().isOk()).andReturn());
    }

    @Test
    void onlyTheOwnerPlansExercisesAndEveryoneInTheGroupSeesThem() throws Exception {
        String walk = "{\"title\":\"Đi bộ\",\"time\":\"06:30\",\"daysOfWeek\":[1,3,5],\"durationMin\":20}";
        mvc.perform(json(as(member, post(base + "/exercises")), walk)).andExpect(status().isForbidden());
        mvc.perform(json(as(outsider, post(base + "/exercises")), walk)).andExpect(status().isNotFound());
        mvc.perform(json(as(elder, post(base + "/exercises")), walk)).andExpect(status().isForbidden());
        Long id = createExercise(walk);
        mvc.perform(as(member, get(base + "/exercises"))).andExpect(status().isOk())
                .andExpect(jsonPath("$[0].title").value("Đi bộ"))
                .andExpect(jsonPath("$[0].daysOfWeek.length()").value(3))
                .andExpect(jsonPath("$[0].durationMin").value(20));
        mvc.perform(json(as(member, put("/api/groups/" + groupId + "/exercises/" + id)), walk)).andExpect(status().isForbidden());
        mvc.perform(as(member, delete("/api/groups/" + groupId + "/exercises/" + id))).andExpect(status().isForbidden());
        // The elder's phone gets it with the schedule, so the alarm works offline.
        mvc.perform(as(elder, get("/api/me/schedule"))).andExpect(status().isOk())
                .andExpect(jsonPath("$.exercises[0].title").value("Đi bộ"))
                .andExpect(jsonPath("$.exercises[0].time").value("06:30"));
    }

    @Test
    void aMondayWednesdayFridayExerciseIsDueOnExactlyThoseDays() throws Exception {
        createExercise("{\"title\":\"Đi bộ\",\"time\":\"06:30\",\"daysOfWeek\":[1,3,5]}");
        LocalDate monday = LocalDate.now(VN).plusDays(1).with(TemporalAdjusters.next(DayOfWeek.MONDAY));
        String cal = calendar(monday, monday.plusDays(13));
        List<Integer> perDay = read(cal, "$[*].exercises");
        // Mon Tue Wed Thu Fri Sat Sun, twice.
        assertThat(perDay).containsExactly(1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0);
    }

    @Test
    void calendarDotsCountTakenMissedAndDoneDays() throws Exception {
        LocalDate today = LocalDate.now(VN);
        LocalDate twoDaysAgo = today.minusDays(2);
        Long med = readId(body(mvc.perform(json(as(owner, post(base + "/medications")), "{\"name\":\"Amlodipin\",\"times\":[\"08:00\"]}"))
                .andExpect(status().isCreated()).andReturn()), "$.id");
        Long ex = createExercise("{\"title\":\"Tập thở\",\"time\":\"07:00\"}");
        // Both started three days ago, so the last two days are real history.
        Timestamp longAgo = Timestamp.from(Instant.now().minusSeconds(5 * 86400));
        jdbc.update("UPDATE medications SET start_date = ?, created_at = ? WHERE id = ?", today.minusDays(3), longAgo, med);
        jdbc.update("UPDATE exercises SET start_date = ?, created_at = ? WHERE id = ?", today.minusDays(3), longAgo, ex);

        mvc.perform(json(as(elder, post("/api/me/dose-reports")), """
                {"clientEventId":"%s","scheduledDate":"%s","scheduledTime":"08:00","medicationIds":[%d],
                 "status":"TAKEN","source":"BUTTON","checkResult":"NONE"}
                """.formatted(UUID.randomUUID(), twoDaysAgo, med))).andExpect(status().isOk());
        String report = "{\"clientEventId\":\"%s\",\"exerciseId\":%d,\"scheduledDate\":\"%s\",\"source\":\"BUTTON\"}"
                .formatted(UUID.randomUUID(), ex, twoDaysAgo);
        mvc.perform(json(as(elder, post("/api/me/exercise-reports")), report))
                .andExpect(status().isOk()).andExpect(jsonPath("$.duplicate").value(false));
        // Resent from the offline queue: same row.
        mvc.perform(json(as(elder, post("/api/me/exercise-reports")), report)).andExpect(jsonPath("$.duplicate").value(true));

        String cal = calendar(twoDaysAgo, today.minusDays(1));
        assertThat((Integer) read(cal, "$[0].taken")).isEqualTo(1);
        assertThat((Integer) read(cal, "$[0].exercisesDone")).isEqualTo(1);
        assertThat((Integer) read(cal, "$[1].missed")).isEqualTo(1);
        assertThat((Integer) read(cal, "$[1].exercisesMissed")).isEqualTo(1);
        // The day view lists the exercise with who did it.
        mvc.perform(as(owner, get(base + "/day?date=" + twoDaysAgo)))
                .andExpect(jsonPath("$.exercises[0].title").value("Tập thở"))
                .andExpect(jsonPath("$.exercises[0].status").value("DONE"));
        assertThat(jdbc.queryForObject("SELECT count(*) FROM exercise_logs WHERE exercise_id = ?", Integer.class, ex)).isEqualTo(1);
    }

    @Test
    void anExerciseReportForADayWithoutThatExerciseIsRefused() throws Exception {
        Long ex = createExercise("{\"title\":\"Đi bộ\",\"time\":\"06:30\",\"daysOfWeek\":[1]}");
        LocalDate tuesday = LocalDate.now(VN).with(TemporalAdjusters.nextOrSame(DayOfWeek.TUESDAY));
        mvc.perform(json(as(elder, post("/api/me/exercise-reports")),
                        "{\"clientEventId\":\"%s\",\"exerciseId\":%d,\"scheduledDate\":\"%s\",\"source\":\"BUTTON\"}"
                                .formatted(UUID.randomUUID(), ex, tuesday)))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("not_scheduled"));
        mvc.perform(json(as(owner, post("/api/me/exercise-reports")),
                        "{\"clientEventId\":\"%s\",\"exerciseId\":%d,\"scheduledDate\":\"%s\",\"source\":\"BUTTON\"}"
                                .formatted(UUID.randomUUID(), ex, tuesday)))
                .andExpect(status().isForbidden());
    }

    @Test
    void changingTheTimeAfterHistoryStartsANewVersionAndDeletingStopsIt() throws Exception {
        LocalDate today = LocalDate.now(VN);
        Long ex = createExercise("{\"title\":\"Đi bộ\",\"time\":\"06:30\"}");
        jdbc.update("UPDATE exercises SET start_date = ? WHERE id = ?", today.minusDays(3), ex);
        mvc.perform(json(as(elder, post("/api/me/exercise-reports")),
                "{\"clientEventId\":\"%s\",\"exerciseId\":%d,\"scheduledDate\":\"%s\",\"source\":\"BUTTON\"}"
                        .formatted(UUID.randomUUID(), ex, today.minusDays(2)))).andExpect(status().isOk());
        Long next = readId(body(mvc.perform(json(as(owner, put("/api/groups/" + groupId + "/exercises/" + ex)),
                "{\"title\":\"Đi bộ\",\"time\":\"17:00\"}")).andExpect(status().isOk()).andReturn()), "$.id");
        assertThat(next).isNotEqualTo(ex);
        assertThat(jdbc.queryForObject("SELECT end_date FROM exercises WHERE id = ?", LocalDate.class, ex)).isEqualTo(today.minusDays(1));
        assertThat(jdbc.queryForObject("SELECT count(*) FROM notification_outbox WHERE user_id = ? AND kind = 'SCHEDULE_CHANGED'",
                Integer.class, elderId)).isGreaterThanOrEqualTo(2);

        mvc.perform(as(owner, delete("/api/groups/" + groupId + "/exercises/" + next))).andExpect(status().isNoContent());
        mvc.perform(as(elder, get("/api/me/schedule"))).andExpect(jsonPath("$.exercises.length()").value(0));
        assertThat(jdbc.queryForObject("SELECT count(*) FROM exercise_logs WHERE exercise_id = ?", Integer.class, ex)).isEqualTo(1);
    }

    @Test
    void theCalendarRangeIsLimitedAndPrivate() throws Exception {
        LocalDate today = LocalDate.now(VN);
        mvc.perform(as(member, get(base + "/calendar?from=" + today + "&to=" + today.plusDays(90)))).andExpect(status().isBadRequest());
        mvc.perform(as(outsider, get(base + "/calendar?from=" + today + "&to=" + today))).andExpect(status().isNotFound());
        mvc.perform(as(elder, get(base + "/calendar?from=" + today + "&to=" + today))).andExpect(status().isForbidden());
    }
}
