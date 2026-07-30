package com.esquilospeak.assessment;

import com.esquilospeak.identityprofile.IdentityProfileService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/mobile/v1/assessments")
class AssessmentController {

    private final AssessmentService service;
    private final IdentityProfileService identities;

    AssessmentController(AssessmentService service, IdentityProfileService identities) {
        this.service = service;
        this.identities = identities;
    }

    @GetMapping("/placement")
    AssessmentService.AssessmentDefinition placement(@AuthenticationPrincipal Jwt jwt) {
        identities.requireLearningAccess(jwt);
        return service.definition();
    }

    @PostMapping("/placement/attempts")
    AssessmentService.AssessmentResult submit(
            @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody AttemptBody body) {
        UUID learnerId = identities.requireLearningAccess(jwt).learnerId();
        return service.submit(learnerId, body.clientAttemptId(), body.answers());
    }

    record AttemptBody(
            @NotNull UUID clientAttemptId,
            @NotEmpty @Size(min = 4, max = 4) List<@NotNull String> answers) {}
}
