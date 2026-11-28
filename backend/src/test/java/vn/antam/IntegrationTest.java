package vn.antam;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.util.UUID;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.testcontainers.postgresql.PostgreSQLContainer;

import com.jayway.jsonpath.JsonPath;

import org.junit.jupiter.api.BeforeEach;

import vn.antam.auth.AttemptLimiter;

/** Base for tests against a real PostgreSQL (same engine and migrations as production) through the full HTTP stack. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public abstract class IntegrationTest {

    /**
     * One database for the whole test run, started once and never stopped by JUnit (Testcontainers
     * removes it when the JVM exits). Spring caches the application context across test classes,
     * so a container stopped after the first class would leave the cached context pointing at a dead port.
     */
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:18");

    static {
        POSTGRES.start();
    }

    @Autowired
    protected MockMvc mvc;

    @Autowired
    private AttemptLimiter limiter;

    @BeforeEach
    void resetAttemptLimits() {
        limiter.clear();
    }

    protected void clearAttemptLimits() {
        limiter.clear();
    }

    /** A signed-in caregiver created for the test. */
    public record Account(Long id, String token, String refreshToken) {
    }

    protected Account registerCaregiver(String name) throws Exception {
        String email = name.toLowerCase().replace(' ', '.') + "." + UUID.randomUUID().toString().substring(0, 8) + "@test.vn";
        String body = """
                {"email":"%s","password":"matkhau123","displayName":"%s","phone":"0900000000"}
                """.formatted(email, name);
        MvcResult r = mvc.perform(post("/api/auth/register").contentType(MediaType.APPLICATION_JSON).content(body)).andReturn();
        if (r.getResponse().getStatus() != 201) throw new AssertionError("register failed: " + r.getResponse().getContentAsString());
        String json = r.getResponse().getContentAsString();
        String token = JsonPath.read(json, "$.accessToken");
        return new Account(meId(token), token, JsonPath.read(json, "$.refreshToken"));
    }

    protected Long meId(String token) throws Exception {
        String json = mvc.perform(get("/api/me").header("Authorization", "Bearer " + token)).andReturn().getResponse().getContentAsString();
        return ((Number) JsonPath.read(json, "$.id")).longValue();
    }

    protected static MockHttpServletRequestBuilder as(Account a, MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + a.token());
    }

    protected static MockHttpServletRequestBuilder json(MockHttpServletRequestBuilder request, String body) {
        return request.contentType(MediaType.APPLICATION_JSON).content(body);
    }

    protected String body(MvcResult r) throws Exception {
        return r.getResponse().getContentAsString();
    }

    protected static <T> T read(String json, String path) {
        return JsonPath.read(json, path);
    }

    protected static Long readId(String json, String path) {
        return ((Number) JsonPath.read(json, path)).longValue();
    }

    protected String pairingCode(Account by, Long group, Long elderUser) throws Exception {
        String code = read(body(mvc.perform(as(by, org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post(
                        "/api/groups/" + group + "/elders/" + elderUser + "/pairing-code")))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.status().isCreated())
                .andReturn()), "$.code");
        org.assertj.core.api.Assertions.assertThat(code).matches("[0-9]{6}");
        return code;
    }

    protected Account pairElder(String code) throws Exception {
        String json = body(mvc.perform(json(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/auth/elder-pair"),
                        "{\"code\":\"" + code + "\",\"deviceName\":\"Test\"}"))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.status().isOk()).andReturn());
        String token = read(json, "$.accessToken");
        return new Account(meId(token), token, read(json, "$.refreshToken"));
    }
}
