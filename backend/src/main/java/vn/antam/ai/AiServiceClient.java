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
        // HTTP/1.1: the JDK client otherwise asks for an h2c upgrade, which uvicorn refuses (and drops the POST body).
        HttpClient http = HttpClient.newBuilder().version(HttpClient.Version.HTTP_1_1).connectTimeout(timeout).build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(http);
        factory.setReadTimeout(timeout);
        this.client = RestClient.builder()
                .baseUrl(baseUrl)
                .requestFactory(factory)
                .defaultHeader(TOKEN_HEADER, token)
                .build();
    }

    /**
     * Suggestions for a document's text, or null when the AI service is down, slow or answers badly.
     * Never logs the text (it can describe someone's illness).
     */
    public vn.antam.ocr.OcrController.ParseResponse parseDocument(String documentType, String text) {
        try {
            return client.post().uri("/v1/documents/parse")
                    .body(java.util.Map.of("document_type", documentType, "text", text))
                    .retrieve()
                    .body(AiParseResponse.class)
                    .toResponse();
        } catch (RuntimeException e) {
            return null;
        }
    }

    /** The AI service's snake_case JSON. */
    record AiParseResponse(java.util.List<AiItem> items, String engine) {
        vn.antam.ocr.OcrController.ParseResponse toResponse() {
            return new vn.antam.ocr.OcrController.ParseResponse(
                    items == null ? java.util.List.of() : items.stream().map(AiItem::toItem).toList(), engine);
        }
    }

    record AiItem(String name, String strength, String dosage, java.util.List<String> times, Integer days, Integer quantity,
                  String note, double confidence, java.util.List<String> uncertain) {
        vn.antam.ocr.OcrController.ParsedItem toItem() {
            return new vn.antam.ocr.OcrController.ParsedItem(name, strength, dosage, times == null ? java.util.List.of() : times,
                    days, quantity, note, confidence, uncertain == null ? java.util.List.of() : uncertain);
        }
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
