package vn.antam.medication;

import java.io.IOException;
import java.util.List;

import jakarta.validation.Valid;

import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import vn.antam.auth.CurrentUser;
import vn.antam.common.ApiException;
import vn.antam.medication.MedicationDtos.ImageInfo;
import vn.antam.medication.MedicationDtos.MedicationRequest;
import vn.antam.medication.MedicationDtos.MedicationResponse;
import vn.antam.medication.MedicationDtos.ScheduleResponse;

@RestController
@RequestMapping("/api")
public class MedicationController {

    private final MedicationService service;

    public MedicationController(MedicationService service) {
        this.service = service;
    }

    @GetMapping("/groups/{groupId}/elders/{elderUserId}/medications")
    public List<MedicationResponse> list(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long elderUserId) {
        return service.list(me, groupId, elderUserId);
    }

    @PostMapping("/groups/{groupId}/elders/{elderUserId}/medications")
    @ResponseStatus(HttpStatus.CREATED)
    public MedicationResponse create(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long elderUserId,
                                     @Valid @RequestBody MedicationRequest r) {
        return service.create(me, groupId, elderUserId, r);
    }

    @PutMapping("/groups/{groupId}/medications/{medicationId}")
    public MedicationResponse update(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long medicationId,
                                     @Valid @RequestBody MedicationRequest r) {
        return service.update(me, groupId, medicationId, r);
    }

    @DeleteMapping("/groups/{groupId}/medications/{medicationId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long medicationId) {
        service.delete(me, groupId, medicationId);
    }

    @PostMapping(path = "/groups/{groupId}/medications/{medicationId}/images", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public ImageInfo addImage(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long medicationId,
                              @RequestPart("file") MultipartFile file,
                              @RequestParam(defaultValue = "PILL") MedicationImage.Kind kind) {
        try {
            return service.addImage(me, groupId, medicationId, kind, file.getBytes());
        } catch (IOException e) {
            throw ApiException.badRequest("upload_failed", "Không đọc được ảnh tải lên.");
        }
    }

    @DeleteMapping("/groups/{groupId}/medications/{medicationId}/images/{imageId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteImage(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long medicationId,
                            @PathVariable Long imageId) {
        service.deleteImage(me, groupId, medicationId, imageId);
    }

    /** Photos are immutable (a new upload gets a new id), so the phone may cache them indefinitely. */
    @GetMapping("/groups/{groupId}/medication-images/{imageId}")
    public ResponseEntity<byte[]> image(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long imageId) {
        MedicationImage img = service.imageFor(me, groupId, imageId);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(img.getMimeType()))
                .cacheControl(CacheControl.maxAge(java.time.Duration.ofDays(365)).cachePrivate())
                .eTag(img.getSha256())
                .body(service.imageBytes(img));
    }

    /** The elder's phone: its own medications, to keep offline and arm alarms from. */
    @GetMapping("/me/schedule")
    public ScheduleResponse mySchedule(@CurrentUser Long me) {
        return service.scheduleForElder(me);
    }
}
