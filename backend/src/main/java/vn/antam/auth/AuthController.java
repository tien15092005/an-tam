package vn.antam.auth;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    public record RegisterRequest(@NotBlank @Email @Size(max = 254) String email,
                                  @NotBlank @Size(min = 8, max = 72) String password,
                                  @NotBlank @Size(max = 100) String displayName,
                                  @Size(max = 20) String phone,
                                  @Size(max = 100) String deviceName) {
    }

    public record LoginRequest(@NotBlank String email, @NotBlank String password, @Size(max = 100) String deviceName) {
    }

    public record RefreshRequest(@NotBlank String refreshToken) {
    }

    public record ElderPairRequest(@NotBlank @Pattern(regexp = "\\d{6}") String code, @Size(max = 100) String deviceName) {
    }

    private final AuthService auth;
    private final TokenService tokens;

    public AuthController(AuthService auth, TokenService tokens) {
        this.auth = auth;
        this.tokens = tokens;
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    public TokenService.TokenPair register(@Valid @RequestBody RegisterRequest r) {
        return auth.register(r.email(), r.password(), r.displayName(), r.phone(), r.deviceName());
    }

    @PostMapping("/login")
    public TokenService.TokenPair login(@Valid @RequestBody LoginRequest r, HttpServletRequest http) {
        return auth.login(r.email(), r.password(), r.deviceName(), http.getRemoteAddr());
    }

    @PostMapping("/refresh")
    public TokenService.TokenPair refresh(@Valid @RequestBody RefreshRequest r) {
        return tokens.refresh(r.refreshToken());
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(@Valid @RequestBody RefreshRequest r) {
        tokens.revoke(r.refreshToken());
    }

    @PostMapping("/elder-pair")
    public TokenService.TokenPair pairElder(@Valid @RequestBody ElderPairRequest r, HttpServletRequest http) {
        return auth.pairElderDevice(r.code(), r.deviceName(), http.getRemoteAddr());
    }
}
