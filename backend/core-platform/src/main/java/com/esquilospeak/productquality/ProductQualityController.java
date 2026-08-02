package com.esquilospeak.productquality;

import com.esquilospeak.identityprofile.IdentityProfileService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
class ProductQualityController {

    private final ProductQualityService service;
    private final IdentityProfileService identities;

    ProductQualityController(ProductQualityService service, IdentityProfileService identities) {
        this.service = service;
        this.identities = identities;
    }

    @PostMapping("/api/mobile/v1/analytics/events")
    ProductQualityService.IngestResult ingest(
            @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody AnalyticsBatch body) {
        UUID learnerId = identities.requireLearningAccess(jwt).learnerId();
        return service.ingest(learnerId, body.events().stream().map(EventBody::toInput).toList());
    }

    @GetMapping("/api/mobile/v1/recommendations/next")
    ProductQualityService.Recommendation recommend(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) @Size(max = 100) String courseId) {
        UUID learnerId = identities.requireLearningAccess(jwt).learnerId();
        return service.recommend(learnerId, courseId);
    }

    @GetMapping("/api/operations/v1/product-quality/dashboard")
    ProductQualityService.Dashboard dashboard(
            @RequestParam @NotBlank @Size(max = 100) String courseId,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to) {
        return service.dashboard(courseId, from, to);
    }

    @GetMapping("/api/operations/v1/content-quality/queue")
    List<ProductQualityService.QualityItem> queue(
            @RequestParam(required = false) @Size(max = 100) String courseId) {
        return service.qualityQueue(courseId);
    }

    @PatchMapping("/api/operations/v1/content-quality/queue/{itemId}/status")
    ProductQualityService.QualityItem updateStatus(
            @PathVariable UUID itemId, @Valid @RequestBody QualityStatus body) {
        return service.updateQualityStatus(itemId, body.status());
    }

    record AnalyticsBatch(@NotEmpty @Size(max = 50) List<@Valid EventBody> events) {}

    record EventBody(
            @NotNull UUID clientEventId,
            @NotBlank @Size(max = 60) String name,
            @Min(1) @Max(1) int eventVersion,
            @NotNull Instant occurredAt,
            @Size(max = 100) String courseId,
            @Size(max = 100) String unitId,
            @Size(max = 100) String lessonId,
            @Min(1) Integer lessonVersion,
            @Size(max = 100) String exerciseId,
            @Size(max = 60) String exerciseType,
            @Size(max = 40) String sessionKind,
            @NotNull @Size(max = 12) Map<@Size(max = 60) String, Object> attributes) {
        ProductQualityService.AnalyticsEventInput toInput() {
            return new ProductQualityService.AnalyticsEventInput(
                    clientEventId,
                    name,
                    eventVersion,
                    occurredAt,
                    courseId,
                    unitId,
                    lessonId,
                    lessonVersion,
                    exerciseId,
                    exerciseType,
                    sessionKind,
                    attributes);
        }
    }

    record QualityStatus(
            @NotBlank @Pattern(regexp = "triaged|resolved|dismissed") String status) {}
}
