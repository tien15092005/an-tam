package vn.antam.health;

import java.time.Instant;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import vn.antam.ai.AiServiceClient;

/** Public endpoint the app uses to check that it can reach the backend (and the backend the AI service). */
@RestController
public class HealthController {

    private final AiServiceClient aiServiceClient;

    public HealthController(AiServiceClient aiServiceClient) {
        this.aiServiceClient = aiServiceClient;
    }

    @GetMapping("/api/health")
    public HealthResponse health() {
        String ai = aiServiceClient.isReachable() ? "UP" : "DOWN";
        return new HealthResponse("UP", ai, Instant.now());
    }

    public record HealthResponse(String status, String ai, Instant serverTime) {
    }
}
