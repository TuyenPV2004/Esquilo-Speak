package com.esquilospeak.reviewscheduler;

import com.esquilospeak.identityprofile.IdentityProfileService;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping("/api/mobile/v1/reviews")
class ReviewController {

    private final ReviewSchedulerService reviewSchedulerService;
    private final IdentityProfileService identityProfileService;
    private final Clock clock;

    ReviewController(
            ReviewSchedulerService reviewSchedulerService,
            IdentityProfileService identityProfileService,
            Clock clock) {
        this.reviewSchedulerService = reviewSchedulerService;
        this.identityProfileService = identityProfileService;
        this.clock = clock;
    }

    @GetMapping
    ReviewQueue queue(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int limit) {
        String learnerId =
                identityProfileService.requireLearningAccess(jwt).learnerId().toString();
        List<ReviewSchedulerService.ReviewItem> items =
                reviewSchedulerService.dueQueue(learnerId, limit);
        return new ReviewQueue(clock.instant(), items);
    }

    record ReviewQueue(Instant generatedAt, List<ReviewSchedulerService.ReviewItem> items) {}
}
