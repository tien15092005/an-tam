package vn.antam.exercise;

import java.util.List;

import jakarta.validation.Valid;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import vn.antam.auth.CurrentUser;
import vn.antam.exercise.ExerciseDtos.ExerciseReportRequest;
import vn.antam.exercise.ExerciseDtos.ExerciseReportResult;
import vn.antam.exercise.ExerciseDtos.ExerciseRequest;
import vn.antam.exercise.ExerciseDtos.ExerciseResponse;

@RestController
@RequestMapping("/api")
public class ExerciseController {

    private final ExerciseService service;

    public ExerciseController(ExerciseService service) {
        this.service = service;
    }

    @GetMapping("/groups/{groupId}/elders/{elderUserId}/exercises")
    public List<ExerciseResponse> list(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long elderUserId) {
        return service.list(me, groupId, elderUserId);
    }

    @PostMapping("/groups/{groupId}/elders/{elderUserId}/exercises")
    public ResponseEntity<ExerciseResponse> create(@CurrentUser Long me, @PathVariable Long groupId,
                                                   @PathVariable Long elderUserId, @Valid @RequestBody ExerciseRequest r) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(me, groupId, elderUserId, r));
    }

    @PutMapping("/groups/{groupId}/exercises/{exerciseId}")
    public ExerciseResponse update(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long exerciseId,
                                   @Valid @RequestBody ExerciseRequest r) {
        return service.update(me, groupId, exerciseId, r);
    }

    @DeleteMapping("/groups/{groupId}/exercises/{exerciseId}")
    public ResponseEntity<Void> delete(@CurrentUser Long me, @PathVariable Long groupId, @PathVariable Long exerciseId) {
        service.delete(me, groupId, exerciseId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/me/exercise-reports")
    public ExerciseReportResult report(@CurrentUser Long me, @Valid @RequestBody ExerciseReportRequest r) {
        try {
            return service.report(me, r);
        } catch (DataIntegrityViolationException raced) {
            return service.report(me, r);
        }
    }
}
