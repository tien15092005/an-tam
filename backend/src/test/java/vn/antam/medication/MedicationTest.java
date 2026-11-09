package vn.antam.medication;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;

import vn.antam.IntegrationTest;

/** Phase 4 DoD: who may change medications, versioning, soft delete, photos, and the elder's schedule feed. */
class MedicationTest extends IntegrationTest {

    @Autowired
    JdbcTemplate jdbc;

    Account owner;
    Account member;
    Account outsider;
    Account elder;
    Long groupId;
    Long elderId;

    static final String AMLODIPIN = """
            {"name":"Amlodipin","strength":"5mg","dosage":"1 viên","shape":"tròn","color":"trắng",
             "pillDescription":"Viên tròn nhỏ màu trắng, có vạch ngang","times":["20:00","07:30"],"daysOfWeek":[]}
            """;

    @BeforeEach
    void family() throws Exception {
        owner = registerCaregiver("Chi Hoa");
        member = registerCaregiver("Anh Nam");
        outsider = registerCaregiver("Nguoi La");
        groupId = readId(body(mvc.perform(json(as(owner, post("/api/groups")), "{\"name\":\"Nhà bà Lan\"}"))
                .andExpect(status().isCreated()).andReturn()), "$.id");
        String invite = read(body(mvc.perform(as(owner, post("/api/groups/" + groupId + "/invites"))).andReturn()), "$.code");
        mvc.perform(json(as(member, post("/api/invites/accept")), "{\"code\":\"" + invite + "\"}")).andExpect(status().isOk());
        elderId = readId(body(mvc.perform(json(as(owner, post("/api/groups/" + groupId + "/elders")),
                "{\"callName\":\"Bà Lan\"}")).andExpect(status().isCreated()).andReturn()), "$.userId");
        String code = read(body(mvc.perform(as(owner, post("/api/groups/" + groupId + "/elders/" + elderId + "/pairing-code")))
                .andReturn()), "$.code");
        String pair = body(mvc.perform(json(post("/api/auth/elder-pair"), "{\"code\":\"" + code + "\",\"deviceName\":\"Test\"}"))
                .andExpect(status().isOk()).andReturn());
        String token = read(pair, "$.accessToken");
        elder = new Account(meId(token), token, read(pair, "$.refreshToken"));
    }

    private String medsUrl() {
        return "/api/groups/" + groupId + "/elders/" + elderId + "/medications";
    }

    private Long create(String body) throws Exception {
        return readId(body(mvc.perform(json(as(owner, post(medsUrl())), body)).andExpect(status().isCreated()).andReturn()), "$.id");
    }

    private long scheduleVersion() throws Exception {
        return ((Number) read(body(mvc.perform(as(elder, get("/api/me/schedule"))).andExpect(status().isOk()).andReturn()),
                "$.scheduleVersion")).longValue();
    }

    @Test
    void onlyTheOwnerChangesMedicationsButEveryoneInTheGroupSeesThem() throws Exception {
        Long id = create(AMLODIPIN);
        for (Account a : List.of(member, elder)) {
            mvc.perform(json(as(a, post(medsUrl())), AMLODIPIN)).andExpect(status().isForbidden());
            mvc.perform(json(as(a, put("/api/groups/" + groupId + "/medications/" + id)), AMLODIPIN)).andExpect(status().isForbidden());
            mvc.perform(as(a, delete("/api/groups/" + groupId + "/medications/" + id))).andExpect(status().isForbidden());
            mvc.perform(as(a, get(medsUrl()))).andExpect(status().isOk()).andExpect(jsonPath("$[0].name").value("Amlodipin"));
        }
        mvc.perform(as(outsider, get(medsUrl()))).andExpect(status().isNotFound());
        mvc.perform(json(as(outsider, post(medsUrl())), AMLODIPIN)).andExpect(status().isNotFound());
        mvc.perform(as(outsider, delete("/api/groups/" + groupId + "/medications/" + id))).andExpect(status().isNotFound());
    }

    @Test
    void theEldersPhoneGetsItsScheduleWithSortedTimesAndDescription() throws Exception {
        long before = scheduleVersion();
        create(AMLODIPIN);
        mvc.perform(as(elder, get("/api/me/schedule"))).andExpect(status().isOk())
                .andExpect(jsonPath("$.callName").value("Bà Lan"))
                .andExpect(jsonPath("$.timezone").value("Asia/Ho_Chi_Minh"))
                .andExpect(jsonPath("$.medications.length()").value(1))
                .andExpect(jsonPath("$.medications[0].times[0]").value("07:30"))
                .andExpect(jsonPath("$.medications[0].times[1]").value("20:00"))
                .andExpect(jsonPath("$.medications[0].daysOfWeek.length()").value(7))
                .andExpect(jsonPath("$.medications[0].pillDescription").value("Viên tròn nhỏ màu trắng, có vạch ngang"));
        assertThat(scheduleVersion()).isGreaterThan(before);
        // Caregivers have no schedule feed of their own.
        mvc.perform(as(owner, get("/api/me/schedule"))).andExpect(status().isForbidden());
    }

    @Test
    void invalidInputIsRejected() throws Exception {
        mvc.perform(json(as(owner, post(medsUrl())), "{\"name\":\"X\",\"times\":[]}")).andExpect(status().isBadRequest());
        mvc.perform(json(as(owner, post(medsUrl())), "{\"name\":\"X\",\"times\":[\"25:00\"]}")).andExpect(status().isBadRequest());
        mvc.perform(json(as(owner, post(medsUrl())), "{\"name\":\"X\",\"times\":[\"08:00\"],\"daysOfWeek\":[8]}")).andExpect(status().isBadRequest());
        mvc.perform(json(as(owner, post(medsUrl())),
                "{\"name\":\"X\",\"times\":[\"08:00\"],\"startDate\":\"2026-11-10\",\"endDate\":\"2026-11-01\"}")).andExpect(status().isBadRequest());
    }

    @Test
    void editingWithoutHistoryChangesInPlace() throws Exception {
        Long id = create(AMLODIPIN);
        String updated = body(mvc.perform(json(as(owner, put("/api/groups/" + groupId + "/medications/" + id)),
                AMLODIPIN.replace("\"07:30\"", "\"08:00\""))).andExpect(status().isOk()).andReturn());
        assertThat(readId(updated, "$.id")).isEqualTo(id);
        mvc.perform(as(elder, get("/api/me/schedule"))).andExpect(jsonPath("$.medications.length()").value(1))
                .andExpect(jsonPath("$.medications[0].times[0]").value("08:00"));
    }

    @Test
    void editingTheScheduleAfterDosesWereLoggedStartsANewVersionAndKeepsHistory() throws Exception {
        LocalDate today = LocalDate.now(ZoneId.of("Asia/Ho_Chi_Minh"));
        Long oldId = create(AMLODIPIN.replace("\"daysOfWeek\":[]", "\"daysOfWeek\":[],\"startDate\":\"" + today.minusDays(7) + "\""));
        String seriesId = read(body(mvc.perform(as(owner, get(medsUrl()))).andReturn()), "$[0].seriesId");
        logDose(oldId, today.minusDays(1));

        String updated = body(mvc.perform(json(as(owner, put("/api/groups/" + groupId + "/medications/" + oldId)),
                AMLODIPIN.replace("\"20:00\",", ""))).andExpect(status().isOk()).andReturn());
        Long newId = readId(updated, "$.id");
        assertThat(newId).isNotEqualTo(oldId);
        assertThat((String) read(updated, "$.seriesId")).isEqualTo(seriesId);
        assertThat((String) read(updated, "$.startDate")).isEqualTo(today.toString());

        mvc.perform(as(elder, get("/api/me/schedule"))).andExpect(jsonPath("$.medications.length()").value(1))
                .andExpect(jsonPath("$.medications[0].id").value(newId))
                .andExpect(jsonPath("$.medications[0].times.length()").value(1));
        // The old version ends yesterday and its dose log is untouched.
        assertThat(jdbc.queryForObject("SELECT end_date FROM medications WHERE id = ?", LocalDate.class, oldId)).isEqualTo(today.minusDays(1));
        assertThat(jdbc.queryForObject("SELECT count(*) FROM dose_logs WHERE medication_id = ?", Integer.class, oldId)).isEqualTo(1);
    }

    @Test
    void deletingStopsRemindersButKeepsHistory() throws Exception {
        Long id = create(AMLODIPIN);
        logDose(id, LocalDate.now(ZoneId.of("Asia/Ho_Chi_Minh")));
        long before = scheduleVersion();
        mvc.perform(as(owner, delete("/api/groups/" + groupId + "/medications/" + id))).andExpect(status().isNoContent());
        mvc.perform(as(elder, get("/api/me/schedule"))).andExpect(jsonPath("$.medications.length()").value(0));
        assertThat(scheduleVersion()).isGreaterThan(before);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM dose_logs WHERE medication_id = ?", Integer.class, id)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM audit_logs WHERE entity_id = ? AND action = 'MEDICATION_DELETED'",
                Integer.class, id)).isEqualTo(1);
        mvc.perform(as(owner, delete("/api/groups/" + groupId + "/medications/" + id))).andExpect(status().isNotFound());
    }

    @Test
    void photosAreReencodedAndTheElderCanDownloadThem() throws Exception {
        Long id = create(AMLODIPIN);
        MockMultipartFile photo = new MockMultipartFile("file", "vien.png", "image/png", png(2400, 1200));
        String info = body(mvc.perform(upload(owner, id, photo).param("kind", "PILL")).andExpect(status().isCreated()).andReturn());
        String url = read(info, "$.url");

        byte[] jpeg = mvc.perform(as(elder, get(url))).andExpect(status().isOk()).andReturn().getResponse().getContentAsByteArray();
        BufferedImage img = ImageIO.read(new java.io.ByteArrayInputStream(jpeg));
        assertThat(Math.max(img.getWidth(), img.getHeight())).isLessThanOrEqualTo(1600);
        assertThat(jpeg[0] & 0xff).isEqualTo(0xff); // JPEG magic
        mvc.perform(as(elder, get("/api/me/schedule"))).andExpect(jsonPath("$.medications[0].images[0].url").value(url));

        mvc.perform(as(outsider, get(url))).andExpect(status().isNotFound());
        mvc.perform(upload(member, id, photo))
                .andExpect(status().isForbidden());
        MockMultipartFile text = new MockMultipartFile("file", "x.png", "image/png", "not an image".getBytes());
        mvc.perform(upload(owner, id, text))
                .andExpect(status().isBadRequest());

        Long imageId = readId(info, "$.id");
        mvc.perform(as(owner, delete("/api/groups/" + groupId + "/medications/" + id + "/images/" + imageId))).andExpect(status().isNoContent());
        mvc.perform(as(elder, get(url))).andExpect(status().isNotFound());
    }

    private org.springframework.test.web.servlet.request.MockMultipartHttpServletRequestBuilder upload(
            Account a, Long medicationId, MockMultipartFile file) {
        var r = multipart("/api/groups/" + groupId + "/medications/" + medicationId + "/images").file(file);
        r.header("Authorization", "Bearer " + a.token());
        return r;
    }

    private void logDose(Long medicationId, LocalDate day) {
        jdbc.update("""
                INSERT INTO dose_logs (medication_id, elder_user_id, scheduled_date, scheduled_time, name_snapshot, status, source,
                                       client_event_id, logged_at, logged_by)
                VALUES (?, ?, ?, '07:30', 'Amlodipin', 'TAKEN', 'BUTTON', ?, now(), ?)
                """, medicationId, elderId, day, UUID.randomUUID(), elderId);
    }

    private static byte[] png(int w, int h) throws Exception {
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(img, "png", out);
        return out.toByteArray();
    }
}
