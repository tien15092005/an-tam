package vn.antam.common;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/** Turns errors into RFC 9457 problem details carrying a "code" the app can switch on. */
@RestControllerAdvice
public class ApiErrorHandler {

    @ExceptionHandler(ApiException.class)
    ProblemDetail handle(ApiException e) {
        ProblemDetail p = ProblemDetail.forStatusAndDetail(e.status(), e.getMessage());
        p.setProperty("code", e.code());
        return p;
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ProblemDetail handle(MethodArgumentNotValidException e) {
        String field = e.getBindingResult().getFieldErrors().stream()
                .map(f -> f.getField())
                .findFirst()
                .orElse("dữ liệu");
        ProblemDetail p = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "Thông tin chưa hợp lệ: " + field + ".");
        p.setProperty("code", "validation");
        p.setProperty("field", field);
        return p;
    }

    /** Malformed JSON or a value of the wrong type (e.g. an unknown enum): same problem format as other errors. */
    @ExceptionHandler(org.springframework.http.converter.HttpMessageNotReadableException.class)
    ProblemDetail handle(org.springframework.http.converter.HttpMessageNotReadableException e) {
        ProblemDetail p = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST,
                "Dữ liệu gửi lên không đúng định dạng.");
        p.setProperty("code", "validation");
        return p;
    }
}
