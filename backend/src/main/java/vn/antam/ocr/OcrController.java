package vn.antam.ocr;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import vn.antam.ai.AiServiceClient;
import vn.antam.auth.CurrentUser;
import vn.antam.common.ApiException;
import vn.antam.group.GroupAccess;

/**
 * "Quét OCR" (plan §8): the phone reads the photo itself and sends only filtered text; this relays it to the
 * internal AI service. Owner only, like adding medicines. The text is never logged or stored.
 */
@RestController
@RequestMapping("/api/groups/{groupId}/ocr")
public class OcrController {

    public enum DocumentType { PRESCRIPTION, PACKAGE, INVOICE, OTHER }

    public record ParseRequest(@NotNull DocumentType documentType, @NotBlank @Size(max = 8000) String text) {
    }

    public record ParsedItem(String name, String strength, String dosage, List<String> times, Integer days, Integer quantity,
                             String note, double confidence, List<String> uncertain) {
    }

    public record ParseResponse(List<ParsedItem> items, String engine) {
    }

    private final GroupAccess access;
    private final AiServiceClient ai;

    public OcrController(GroupAccess access, AiServiceClient ai) {
        this.access = access;
        this.ai = ai;
    }

    @PostMapping("/parse")
    public ParseResponse parse(@CurrentUser Long me, @PathVariable Long groupId, @Valid @RequestBody ParseRequest r) {
        access.requireOwner(groupId, me);
        ParseResponse result = ai.parseDocument(r.documentType().name(), r.text());
        if (result == null) {
            // The app shows the manual form instead (plan §8: AI down never blocks adding medicines).
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "ai_unavailable",
                    "Chưa đọc được giấy tờ lúc này. Bạn có thể nhập tay.");
        }
        return result;
    }
}
