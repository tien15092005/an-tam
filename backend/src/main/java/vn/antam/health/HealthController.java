package vn.antam.health;

import java.time.Instant;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import vn.antam.ai.AiServiceClient;

/** Public endpoint the app uses to check that it can reach the backend (and the backend the AI service). */
@RestController
public class HealthController {

    static final long AI_CHECK_EVERY_MS = 5_000;

    private final AiServiceClient aiServiceClient;
    private volatile String lastAi = "DOWN";
    private volatile long lastAiCheck;

    public HealthController(AiServiceClient aiServiceClient) {
        this.aiServiceClient = aiServiceClient;
    }

    @GetMapping("/api/health")
    public HealthResponse health() {
        return new HealthResponse("UP", aiStatus(), Instant.now());
    }

    /** Tests switch the AI answer between calls. */
    void forgetCachedAiStatus() {
        lastAiCheck = 0;
    }

    /** The AI check is reused for a few seconds, so this public endpoint cannot be used to load the AI service. */
    private String aiStatus() {
        long now = System.currentTimeMillis();
        if (lastAiCheck == 0 || now - lastAiCheck >= AI_CHECK_EVERY_MS) {
            synchronized (this) {
                if (lastAiCheck == 0 || now - lastAiCheck >= AI_CHECK_EVERY_MS) {
                    lastAi = aiServiceClient.isReachable() ? "UP" : "DOWN";
                    lastAiCheck = System.currentTimeMillis();
                }
            }
        }
        return lastAi;
    }

    public record HealthResponse(String status, String ai, Instant serverTime) {
    }
}
