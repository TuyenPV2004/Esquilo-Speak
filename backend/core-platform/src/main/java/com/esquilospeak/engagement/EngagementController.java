package com.esquilospeak.engagement;

import com.esquilospeak.identityprofile.IdentityProfileService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalTime;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/mobile/v1/engagement")
class EngagementController {

    private final EngagementService service;
    private final IdentityProfileService identities;

    EngagementController(EngagementService service, IdentityProfileService identities) {
        this.service = service;
        this.identities = identities;
    }

    @GetMapping
    EngagementService.EngagementStatus status(@AuthenticationPrincipal Jwt jwt) {
        return service.status(identities.requireLearningAccess(jwt).learnerId());
    }

    @PostMapping("/activities")
    EngagementService.EngagementStatus activity(
            @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody ActivityBody body) {
        return service.recordActivity(
                identities.requireLearningAccess(jwt).learnerId(),
                body.clientEventId(),
                body.eventType(),
                body.evidenceRef());
    }

    @PutMapping("/notification-preference")
    EngagementService.NotificationPreference preference(
            @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody PreferenceBody body) {
        return service.updatePreference(
                identities.requireLearningAccess(jwt).learnerId(),
                body.enabled(),
                body.reminderTime(),
                body.locale(),
                body.timezone());
    }

    record ActivityBody(
            @NotNull UUID clientEventId,
            @NotBlank @Size(max = 40) String eventType,
            @Size(max = 160) String evidenceRef) {}

    record PreferenceBody(
            boolean enabled,
            LocalTime reminderTime,
            @NotBlank @Size(max = 35) String locale,
            @NotBlank @Size(max = 80) String timezone) {}
}
