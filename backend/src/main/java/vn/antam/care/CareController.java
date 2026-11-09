package vn.antam.care;

import java.time.LocalDate;
import java.util.List;

import jakarta.validation.Valid;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import vn.antam.auth.CurrentUser;
import vn.antam.care.CareDtos.AlertResponse;
import vn.antam.care.CareDtos.CalendarDay;
import vn.antam.care.CareDtos.DayView;
import vn.antam.care.CareDtos.MarkRequest;
import vn.antam.care.CareDtos.MarkResult;
import vn.antam.care.CareDtos.DoseLogResponse;
import vn.antam.care.CareDtos.DoseReportRequest;
import vn.antam.care.CareDtos.DoseReportResult;
import vn.antam.care.CareDtos.ElderAlertRequest;

@RestController
@RequestMapping("/api")
public class CareController {

    private final CareService service;
    private final TodayService today;

    public CareController(CareService service, TodayService today) {
        this.service = service;
        this.today = today;
    }

    /** The elder's phone, after an alarm. Safe to resend: the same clientEventId returns the stored result. */
    @PostMapping("/me/dose-reports")
    public DoseReportResult report(@CurrentUser Long me, @Valid @RequestBody DoseReportRequest r) {
        try {
            return service.report(me, r);
        } catch (DataIntegrityViolationException raced) {
            // Two copies arrived at the same moment; the other one won, so answer as a resend.
            return service.report(me, r);
        }
    }

    @PostMapping("/me/alerts")
    public AlertResponse elderAlert(@CurrentUser Long me, @Valid @RequestBody ElderAlertRequest r) {
        try {
            return service.elderAlert(me, r);
        } catch (DataIntegrityViolationException raced) {
            return service.elderAlert(me, r);
        }
    }

    @GetMapping("/groups/{groupId}/alerts")
    public List<AlertResponse> alerts(@CurrentUser Long me, @PathVariable Long groupId,
                                      @RequestParam(defaultValue = "true") boolean openOnly) {
        return service.alerts(me, groupId, openOnly);
    }

    @PostMapping("/groups/{groupId}/alerts/{alertId}/resolve")
    public AlertResponse resolve(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long alertId) {
        return service.resolve(me, groupId, alertId);
    }

    @GetMapping("/groups/{groupId}/elders/{elderUserId}/doses")
    public List<DoseLogResponse> doses(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long elderUserId,
                                       @RequestParam LocalDate date) {
        return service.dosesOn(me, groupId, elderUserId, date);
    }

    /** The caregiver's "Hôm nay" timeline for one elder (any date in the last week works the same). */
    @GetMapping("/groups/{groupId}/elders/{elderUserId}/day")
    public DayView day(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long elderUserId,
                       @RequestParam LocalDate date) {
        return today.day(me, groupId, elderUserId, date);
    }

    @GetMapping("/groups/{groupId}/elders/{elderUserId}/calendar")
    public List<CalendarDay> calendar(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long elderUserId,
                                      @RequestParam LocalDate from, @RequestParam LocalDate to) {
        return today.calendar(me, groupId, elderUserId, from, to);
    }

    @PostMapping("/groups/{groupId}/elders/{elderUserId}/doses")
    public MarkResult mark(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long elderUserId,
                           @Valid @RequestBody MarkRequest r) {
        try {
            return today.mark(me, groupId, elderUserId, r);
        } catch (DataIntegrityViolationException raced) {
            // Elder's answer (or another caregiver) arrived at the same moment: report what is stored now.
            return today.mark(me, groupId, elderUserId, r);
        }
    }

    @DeleteMapping("/groups/{groupId}/elders/{elderUserId}/doses/{doseLogId}")
    public ResponseEntity<Void> undo(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long elderUserId,
                                     @PathVariable Long doseLogId) {
        today.undo(me, groupId, elderUserId, doseLogId);
        return ResponseEntity.noContent().build();
    }
}
