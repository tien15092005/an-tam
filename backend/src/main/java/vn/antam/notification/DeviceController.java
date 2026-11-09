package vn.antam.notification;

import java.time.Clock;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import vn.antam.auth.CurrentUser;

/** The app registers its FCM token after sign-in and whenever Firebase rotates it. */
@RestController
@RequestMapping("/api/me/device")
public class DeviceController {

    public record DeviceRequest(@NotBlank @Size(max = 512) String fcmToken,
                                @Pattern(regexp = "ANDROID|IOS") String platform) {
    }

    private final DeviceRepository devices;
    private final Clock clock;

    public DeviceController(DeviceRepository devices, Clock clock) {
        this.devices = devices;
        this.clock = clock;
    }

    @PutMapping
    @Transactional
    public ResponseEntity<Void> register(@CurrentUser Long me, @Valid @RequestBody DeviceRequest r) {
        String platform = r.platform() == null ? "ANDROID" : r.platform();
        devices.findByFcmToken(r.fcmToken()).ifPresentOrElse(
                d -> d.seen(me, platform, clock.instant()),
                () -> devices.save(new Device(me, r.fcmToken(), platform, clock.instant())));
        return ResponseEntity.noContent().build();
    }

    /** On sign-out, so this phone stops receiving the account's notifications. */
    @DeleteMapping
    @Transactional
    public ResponseEntity<Void> unregister(@CurrentUser Long me, @Valid @RequestBody DeviceRequest r) {
        devices.findByFcmToken(r.fcmToken()).filter(d -> d.getUserId().equals(me)).ifPresent(devices::delete);
        return ResponseEntity.noContent().build();
    }
}
