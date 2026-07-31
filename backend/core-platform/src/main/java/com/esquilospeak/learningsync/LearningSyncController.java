package com.esquilospeak.learningsync;

import com.esquilospeak.identityprofile.IdentityProfileService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping("/api/mobile/v1/sync")
class LearningSyncController {

    private final LearningSyncService syncService;
    private final IdentityProfileService identityProfileService;

    LearningSyncController(
            LearningSyncService syncService, IdentityProfileService identityProfileService) {
        this.syncService = syncService;
        this.identityProfileService = identityProfileService;
    }

    @PostMapping("/push")
    LearningSyncService.PushResult push(
            @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody PushBody body) {
        String learnerId =
                identityProfileService.requireLearningAccess(jwt).learnerId().toString();
        return syncService.push(learnerId, body.toRequest());
    }

    @GetMapping("/pull")
    LearningSyncService.PullResult pull(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "50") @Min(1) @Max(100) int limit) {
        String learnerId =
                identityProfileService.requireLearningAccess(jwt).learnerId().toString();
        return syncService.pull(learnerId, cursor, limit);
    }

    record PushBody(
            @NotNull UUID clientBatchId,
            String baseCursor,
            @NotEmpty @Size(max = 100) List<@Valid MutationBody> mutations) {

        LearningSyncService.PushRequest toRequest() {
            return new LearningSyncService.PushRequest(
                    clientBatchId,
                    baseCursor,
                    mutations.stream().map(MutationBody::toMutation).toList());
        }
    }

    record MutationBody(
            @NotNull UUID clientMutationId,
            @NotBlank String type,
            @NotNull UUID idempotencyKey,
            @NotNull Map<String, Object> payload) {

        LearningSyncService.PushMutation toMutation() {
            return new LearningSyncService.PushMutation(
                    clientMutationId, type, idempotencyKey, payload);
        }
    }
}
