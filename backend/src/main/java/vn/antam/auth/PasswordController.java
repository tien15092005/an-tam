package vn.antam.auth;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import vn.antam.common.ClientIp;

/** Change a password, or reset a forgotten one with a code from a sibling (no e-mail needed). */
@RestController
public class PasswordController {

    public record ChangePasswordRequest(@NotBlank @Size(max = 72) String currentPassword,
                                        @NotBlank @Size(min = 8, max = 72) String newPassword,
                                        @Size(max = 100) String deviceName) {
    }

    public record ResetPasswordRequest(@NotBlank @Email @Size(max = 254) String email,
                                       @NotBlank @Size(max = 20) String code,
                                       @NotBlank @Size(min = 8, max = 72) String newPassword,
                                       @Size(max = 100) String deviceName) {
    }

    private final PasswordService passwords;

    public PasswordController(PasswordService passwords) {
        this.passwords = passwords;
    }

    @PostMapping("/api/me/password")
    public TokenService.TokenPair change(@CurrentUser Long me, @Valid @RequestBody ChangePasswordRequest r) {
        return passwords.change(me, r.currentPassword(), r.newPassword(), r.deviceName());
    }

    @PostMapping("/api/groups/{groupId}/members/{userId}/password-reset")
    @ResponseStatus(HttpStatus.CREATED)
    public PasswordService.ResetCode createResetCode(@CurrentUser Long me, @PathVariable Long groupId,
                                                     @PathVariable Long userId) {
        return passwords.createResetCode(me, groupId, userId);
    }

    @PostMapping("/api/auth/password-reset")
    public TokenService.TokenPair reset(@Valid @RequestBody ResetPasswordRequest r, HttpServletRequest http) {
        return passwords.reset(r.email(), r.code(), r.newPassword(), r.deviceName(), ClientIp.of(http));
    }
}
