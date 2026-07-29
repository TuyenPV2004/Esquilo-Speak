package com.esquilospeak.learning;

import com.esquilospeak.identityprofile.IdentityProfileService;
import com.esquilospeak.identityprofile.IdentityProfileService.LearnerContext;
import com.esquilospeak.learning.LearningService.AttemptRequest;
import com.esquilospeak.learning.LearningService.AttemptResult;
import com.esquilospeak.learning.LearningService.CourseProgress;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import java.time.Instant;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping("/api/mobile/v1")
class LearningController {

    private static final String IDENTIFIER = "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$";

    private final LearningService learningService;
    private final IdentityProfileService identityProfileService;

    LearningController(
            LearningService learningService,
            IdentityProfileService identityProfileService) {
        this.learningService = learningService;
        this.identityProfileService = identityProfileService;
    }

    @PostMapping("/attempts")
    AttemptResult submit(
            @AuthenticationPrincipal Jwt jwt,
            @RequestHeader("Idempotency-Key") UUID idempotencyKey,
            @Valid @RequestBody AttemptBody body) {
        LearnerContext learner = identityProfileService.requireLearningAccess(jwt);
        return learningService.submit(
                learner.learnerId().toString(), idempotencyKey, body.toRequest());
    }

    @GetMapping("/progress/courses/{courseId}")
    CourseProgress progress(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable @Pattern(regexp = IDENTIFIER) String courseId) {
        LearnerContext learner = identityProfileService.requireLearningAccess(jwt);
        return learningService.progress(learner.learnerId().toString(), courseId);
    }

    record AttemptBody(
            @NotNull UUID clientAttemptId,
            @NotBlank @Pattern(regexp = IDENTIFIER) String courseId,
            @NotBlank @Pattern(regexp = IDENTIFIER) String lessonId,
            @Positive int lessonVersion,
            @NotBlank @Pattern(regexp = IDENTIFIER) String exerciseId,
            @NotBlank @Pattern(regexp = IDENTIFIER) String selectedOptionId,
            @NotNull Instant occurredAt,
            @PositiveOrZero Integer responseTimeMs) {

        AttemptRequest toRequest() {
            return new AttemptRequest(
                    clientAttemptId,
                    courseId,
                    lessonId,
                    lessonVersion,
                    exerciseId,
                    selectedOptionId,
                    occurredAt,
                    responseTimeMs);
        }
    }
}
