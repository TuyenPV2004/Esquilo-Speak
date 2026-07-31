package com.esquilospeak.mastery;

import com.esquilospeak.identityprofile.IdentityProfileService;
import java.util.List;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/mobile/v1/mastery")
class MasteryController {

    private final MasteryService masteryService;
    private final IdentityProfileService identityProfileService;

    MasteryController(
            MasteryService masteryService, IdentityProfileService identityProfileService) {
        this.masteryService = masteryService;
        this.identityProfileService = identityProfileService;
    }

    @GetMapping
    MasteryResponse states(@AuthenticationPrincipal Jwt jwt) {
        String learnerId =
                identityProfileService.requireLearningAccess(jwt).learnerId().toString();
        return new MasteryResponse(MasteryService.MODEL_VERSION, masteryService.states(learnerId));
    }

    record MasteryResponse(int modelVersion, List<MasteryService.MasteryState> items) {}
}
