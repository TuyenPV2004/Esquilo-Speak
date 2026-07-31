package com.esquilospeak.identityprofile;

import com.esquilospeak.identityprofile.IdentityProfileService.AgeBand;
import com.esquilospeak.identityprofile.IdentityProfileService.ConsentPurpose;
import com.esquilospeak.identityprofile.IdentityProfileService.ConsentRecord;
import com.esquilospeak.identityprofile.IdentityProfileService.LearnerContext;
import com.esquilospeak.identityprofile.IdentityProfileService.LearnerProfile;
import com.esquilospeak.identityprofile.IdentityProfileService.MergeResult;
import com.esquilospeak.identityprofile.IdentityProfileService.MergeTicket;
import com.esquilospeak.identityprofile.IdentityProfileService.ProfileUpdate;
import com.esquilospeak.identityprofile.PrivacyRequestService.PrivacyRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping("/api/mobile/v1/me")
class IdentityProfileController {

    private static final String LOCALE = "^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$";

    private final IdentityProfileService identityProfileService;
    private final PrivacyRequestService privacyRequestService;

    IdentityProfileController(
            IdentityProfileService identityProfileService,
            PrivacyRequestService privacyRequestService) {
        this.identityProfileService = identityProfileService;
        this.privacyRequestService = privacyRequestService;
    }

    @GetMapping("/profile")
    ProfileResponse profile(@AuthenticationPrincipal Jwt jwt) {
        LearnerContext learner = identityProfileService.resolve(jwt);
        return ProfileResponse.from(identityProfileService.profile(learner));
    }

    @PutMapping("/profile")
    ProfileResponse updateProfile(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody ProfileBody body) {
        LearnerContext learner = identityProfileService.resolve(jwt);
        LearnerProfile profile = identityProfileService.updateProfile(
                learner,
                new ProfileUpdate(
                        body.uiLocale(),
                        body.sourceLanguage(),
                        body.targetLanguage(),
                        AgeBand.fromApi(body.ageBand()),
                        body.learningGoal(),
                        body.preferences() == null ? Map.of() : body.preferences()));
        return ProfileResponse.from(profile);
    }

    @GetMapping("/consents")
    ItemsResponse<ConsentResponse> consents(@AuthenticationPrincipal Jwt jwt) {
        LearnerContext learner = identityProfileService.resolve(jwt);
        return new ItemsResponse<>(identityProfileService.consents(learner).stream()
                .map(ConsentResponse::from)
                .toList());
    }

    @PutMapping("/consents/{purpose}")
    ConsentResponse recordConsent(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String purpose,
            @Valid @RequestBody ConsentBody body) {
        LearnerContext learner = identityProfileService.resolve(jwt);
        return ConsentResponse.from(identityProfileService.recordConsent(
                learner,
                ConsentPurpose.fromValue(purpose),
                body.policyVersion(),
                body.granted()));
    }

    @PostMapping("/guest-merge-tickets")
    @ResponseStatus(HttpStatus.CREATED)
    MergeTicketResponse createMergeTicket(@AuthenticationPrincipal Jwt jwt) {
        LearnerContext learner = identityProfileService.resolve(jwt);
        MergeTicket ticket = identityProfileService.createMergeTicket(learner);
        return new MergeTicketResponse(ticket.mergeTicket(), ticket.expiresAt());
    }

    @PostMapping("/guest-merges")
    MergeResponse mergeGuest(
            @AuthenticationPrincipal Jwt jwt,
            @RequestHeader("Idempotency-Key") UUID idempotencyKey,
            @Valid @RequestBody MergeBody body) {
        LearnerContext account = identityProfileService.resolve(jwt);
        MergeResult result =
                identityProfileService.mergeGuest(account, idempotencyKey, body.mergeTicket());
        return new MergeResponse(
                result.guestLearnerId(), result.accountLearnerId(), result.mergedAt());
    }

    @PostMapping("/privacy/exports")
    @ResponseStatus(HttpStatus.ACCEPTED)
    PrivacyResponse requestExport(
            @AuthenticationPrincipal Jwt jwt,
            @RequestHeader("Idempotency-Key") UUID idempotencyKey) {
        LearnerContext learner = identityProfileService.resolve(jwt);
        return PrivacyResponse.from(privacyRequestService.requestExport(learner, idempotencyKey));
    }

    @PostMapping("/privacy/deletions")
    @ResponseStatus(HttpStatus.ACCEPTED)
    PrivacyResponse requestDeletion(
            @AuthenticationPrincipal Jwt jwt,
            @RequestHeader("Idempotency-Key") UUID idempotencyKey) {
        LearnerContext learner = identityProfileService.resolve(jwt);
        return PrivacyResponse.from(privacyRequestService.requestDeletion(learner, idempotencyKey));
    }

    @GetMapping("/privacy/requests/{requestId}")
    PrivacyResponse privacyRequest(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID requestId) {
        LearnerContext learner = identityProfileService.resolveForPrivacyStatus(jwt);
        return PrivacyResponse.from(privacyRequestService.status(learner, requestId));
    }

    record ProfileBody(
            @NotBlank @Pattern(regexp = LOCALE) String uiLocale,
            @NotBlank @Pattern(regexp = LOCALE) String sourceLanguage,
            @NotBlank @Pattern(regexp = LOCALE) String targetLanguage,
            @NotBlank @Pattern(regexp = "^(under_16|16_17|adult)$") String ageBand,
            @Size(max = 50) String learningGoal,
            Map<String, Object> preferences) {}

    record ConsentBody(
            @NotBlank @Size(max = 50) String policyVersion,
            @NotNull Boolean granted) {}

    record MergeBody(@NotBlank @Size(max = 200) String mergeTicket) {}

    record ProfileResponse(
            UUID learnerId,
            String actorType,
            String uiLocale,
            String sourceLanguage,
            String targetLanguage,
            String ageBand,
            String learningGoal,
            Map<String, Object> preferences,
            Instant updatedAt) {

        static ProfileResponse from(LearnerProfile profile) {
            return new ProfileResponse(
                    profile.learnerId(),
                    profile.actorType().name().toLowerCase(),
                    profile.uiLocale(),
                    profile.sourceLanguage(),
                    profile.targetLanguage(),
                    profile.ageBand() == null ? null : profile.ageBand().value(),
                    profile.learningGoal(),
                    profile.preferences(),
                    profile.updatedAt());
        }
    }

    record ConsentResponse(
            String purpose,
            String policyVersion,
            boolean granted,
            Instant recordedAt) {

        static ConsentResponse from(ConsentRecord record) {
            return new ConsentResponse(
                    record.purpose().value(),
                    record.policyVersion(),
                    record.granted(),
                    record.recordedAt());
        }
    }

    record MergeTicketResponse(String mergeTicket, Instant expiresAt) {}

    record MergeResponse(
            UUID guestLearnerId,
            UUID accountLearnerId,
            Instant mergedAt) {}

    record PrivacyResponse(
            UUID requestId,
            String requestType,
            String state,
            Instant requestedAt,
            Instant targetAt,
            Instant completedAt,
            Map<String, Object> artifact,
            Instant artifactExpiresAt,
            String failureCode) {

        static PrivacyResponse from(PrivacyRequest request) {
            return new PrivacyResponse(
                    request.requestId(),
                    request.requestType().name().toLowerCase(),
                    request.state().name().toLowerCase(),
                    request.requestedAt(),
                    request.targetAt(),
                    request.completedAt(),
                    request.artifact(),
                    request.artifactExpiresAt(),
                    request.failureCode());
        }
    }

    record ItemsResponse<T>(List<T> items) {}
}
