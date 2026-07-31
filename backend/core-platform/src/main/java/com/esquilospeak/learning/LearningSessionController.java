package com.esquilospeak.learning;

import com.esquilospeak.identityprofile.IdentityProfileService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping("/api/mobile/v1/learning-sessions")
class LearningSessionController {

    private static final String IDENTIFIER = "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$";

    private final LearningSessionService sessionService;
    private final IdentityProfileService identityProfileService;

    LearningSessionController(
            LearningSessionService sessionService,
            IdentityProfileService identityProfileService) {
        this.sessionService = sessionService;
        this.identityProfileService = identityProfileService;
    }

    @PostMapping
    LearningSessionService.SessionResult start(
            @AuthenticationPrincipal Jwt jwt,
            @RequestHeader("Idempotency-Key") UUID idempotencyKey,
            @Valid @RequestBody StartSessionBody body) {
        String learnerId =
                identityProfileService.requireLearningAccess(jwt).learnerId().toString();
        return sessionService.start(
                learnerId,
                idempotencyKey,
                body.clientSessionId(),
                body.courseId(),
                body.contentVersion());
    }

    @PostMapping("/{sessionId}/completion")
    LearningSessionService.SessionResult complete(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID sessionId) {
        String learnerId =
                identityProfileService.requireLearningAccess(jwt).learnerId().toString();
        return sessionService.complete(learnerId, sessionId);
    }

    record StartSessionBody(
            @NotNull UUID clientSessionId,
            @NotBlank @Pattern(regexp = IDENTIFIER) String courseId,
            @Positive int contentVersion) {}
}
