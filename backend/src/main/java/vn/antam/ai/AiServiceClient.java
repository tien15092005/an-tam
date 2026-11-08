package vn.antam.ai;

import java.net.http.HttpClient;
import java.time.Duration;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

/** Calls the internal AI service. Every request carries the shared service token. */
@Component
public class AiServiceClient {

    static final String TOKEN_HEADER = "X-Service-Token";

    private final RestClient client;

    public AiServiceClient(@Value("${antam.ai.base-url}") String baseUrl,
                           @Value("${antam.ai.token}") String token,
                           @Value("${antam.ai.timeout:5s}") Duration timeout) {
        HttpClient http = HttpClient.newBuilder().connectTimeout(timeout).build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(http);
        factory.setReadTimeout(timeout);
        this.client = RestClient.builder()
                .baseUrl(baseUrl)
                .requestFactory(factory)
                .defaultHeader(TOKEN_HEADER, token)
                .build();
    }

    /** True when the AI service answers an authenticated ping. Never throws. */
    public boolean isReachable() {
        try {
            client.get().uri("/v1/ping").retrieve().toBodilessEntity();
            return true;
        } catch (RestClientException e) {
            return false;
        }
    }
}
