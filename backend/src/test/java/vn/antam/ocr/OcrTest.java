package vn.antam.ocr;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.concurrent.atomic.AtomicReference;

import org.junit.jupiter.api.Test;

import com.sun.net.httpserver.HttpServer;

import vn.antam.IntegrationTest;
import vn.antam.ai.AiServiceClient;

/** Phase 8: OCR text goes to the AI service only for the owner; when the AI is down the app gets a clear 503. */
class OcrTest extends IntegrationTest {

    @Test
    void onlyTheOwnerCanScanAndAnAiOutageIsReportedSoTheAppOffersManualEntry() throws Exception {
        Account owner = registerCaregiver("Chi Hoa");
        Account member = registerCaregiver("Anh Nam");
        Account outsider = registerCaregiver("Nguoi La");
        Long groupId = readId(body(mvc.perform(json(as(owner, post("/api/groups")), "{\"name\":\"Nhà\"}")).andReturn()), "$.id");
        String invite = read(body(mvc.perform(as(owner, post("/api/groups/" + groupId + "/invites"))).andReturn()), "$.code");
        mvc.perform(json(as(member, post("/api/invites/accept")), "{\"code\":\"" + invite + "\"}")).andExpect(status().isOk());

        String url = "/api/groups/" + groupId + "/ocr/parse";
        String body = "{\"documentType\":\"PRESCRIPTION\",\"text\":\"1. Amlodipin 5mg 30 viên\"}";
        mvc.perform(json(as(member, post(url)), body)).andExpect(status().isForbidden());
        mvc.perform(json(as(outsider, post(url)), body)).andExpect(status().isNotFound());
        mvc.perform(json(as(owner, post(url)), "{\"documentType\":\"PRESCRIPTION\",\"text\":\"\"}")).andExpect(status().isBadRequest());
        mvc.perform(json(as(owner, post(url)), "{\"documentType\":\"PRESCRIPTION\",\"text\":\"" + "a".repeat(8001) + "\"}"))
                .andExpect(status().isBadRequest());
        // No AI service runs in tests: the owner gets 503 ai_unavailable, not a crash.
        mvc.perform(json(as(owner, post(url)), body))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("ai_unavailable"));
    }

    @Test
    void theClientSendsTheTokenAndMapsTheAiAnswer() throws Exception {
        AtomicReference<String> token = new AtomicReference<>();
        AtomicReference<String> upgrade = new AtomicReference<>();
        AtomicReference<String> sent = new AtomicReference<>();
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/documents/parse", ex -> {
            token.set(ex.getRequestHeaders().getFirst("X-Service-Token"));
            upgrade.set(ex.getRequestHeaders().getFirst("Upgrade"));
            sent.set(new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            byte[] out = """
                    {"items":[{"name":"Losartan","strength":"50mg","dosage":"1/2 viên","times":["07:30"],"days":null,
                     "quantity":null,"note":null,"confidence":0.8,"uncertain":["days"]}],"engine":"baseline-rules-v1"}
                    """.getBytes(StandardCharsets.UTF_8);
            ex.getResponseHeaders().add("Content-Type", "application/json");
            ex.sendResponseHeaders(200, out.length);
            ex.getResponseBody().write(out);
            ex.close();
        });
        server.start();
        try {
            AiServiceClient client = new AiServiceClient("http://127.0.0.1:" + server.getAddress().getPort(), "secret",
                    Duration.ofSeconds(2));
            OcrController.ParseResponse r = client.parseDocument("PRESCRIPTION", "6. Losartan 50mg\nSáng: 1/2 viên");
            assertThat(token.get()).isEqualTo("secret");
            assertThat(upgrade.get()).as("no h2c upgrade: uvicorn drops the body").isNull();
            assertThat(sent.get()).contains("\"document_type\":\"PRESCRIPTION\"").contains("Losartan");
            assertThat(r.engine()).isEqualTo("baseline-rules-v1");
            assertThat(r.items()).singleElement().satisfies(i -> {
                assertThat(i.name()).isEqualTo("Losartan");
                assertThat(i.times()).containsExactly("07:30");
                assertThat(i.uncertain()).containsExactly("days");
            });
        } finally {
            server.stop(0);
        }
    }
}
