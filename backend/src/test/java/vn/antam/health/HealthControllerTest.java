package vn.antam.health;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import vn.antam.ai.AiServiceClient;
import vn.antam.auth.SecurityConfig;

@WebMvcTest(HealthController.class)
@Import(SecurityConfig.class)
@ActiveProfiles("test")
class HealthControllerTest {

    @Autowired
    MockMvc mvc;

    @MockitoBean
    AiServiceClient aiServiceClient;

    /** SecurityConfig's locked-account check reads users; not used by these anonymous calls. */
    @MockitoBean
    org.springframework.jdbc.core.JdbcTemplate jdbc;

    @Autowired
    HealthController controller;

    @org.junit.jupiter.api.BeforeEach
    void freshAiCheck() {
        controller.forgetCachedAiStatus();
    }

    @Test
    void theAiCheckIsReusedForAFewSeconds() throws Exception {
        when(aiServiceClient.isReachable()).thenReturn(true);
        for (int i = 0; i < 5; i++) mvc.perform(get("/api/health")).andExpect(status().isOk());
        org.mockito.Mockito.verify(aiServiceClient, org.mockito.Mockito.times(1)).isReachable();
    }

    @Test
    void isPublicAndReportsAiUpWhenReachable() throws Exception {
        when(aiServiceClient.isReachable()).thenReturn(true);
        mvc.perform(get("/api/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.ai").value("UP"))
                .andExpect(jsonPath("$.serverTime").exists());
    }

    @Test
    void staysUpButReportsAiDownWhenAiUnreachable() throws Exception {
        when(aiServiceClient.isReachable()).thenReturn(false);
        mvc.perform(get("/api/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.ai").value("DOWN"));
    }
}
