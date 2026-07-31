package com.esquilospeak.commerceentitlement;

import com.esquilospeak.identityprofile.IdentityProfileService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
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
@RequestMapping("/api/mobile/v1/commerce")
class CommerceEntitlementController {

    private final CommerceEntitlementService service;
    private final IdentityProfileService identities;

    CommerceEntitlementController(
            CommerceEntitlementService service, IdentityProfileService identities) {
        this.service = service;
        this.identities = identities;
    }

    @GetMapping("/entitlements")
    List<CommerceEntitlementService.EntitlementResult> entitlements(
            @AuthenticationPrincipal Jwt jwt) {
        return service.entitlements(identities.requireLearningAccess(jwt).learnerId());
    }

    @PostMapping("/purchases/verify")
    CommerceEntitlementService.EntitlementResult verify(
            @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody PurchaseBody body) {
        UUID learnerId = identities.requireLearningAccess(jwt).learnerId();
        return service.verify(
                learnerId, body.purchaseToken(), body.productId(), "purchase_verified");
    }

    @PostMapping("/purchases/refund")
    CommerceEntitlementService.EntitlementResult refund(
            @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody PurchaseBody body) {
        UUID learnerId = identities.requireLearningAccess(jwt).learnerId();
        return service.verify(
                learnerId, body.purchaseToken(), body.productId(), "refund_verified");
    }

    record PurchaseBody(
            @NotBlank @Size(max = 4096) String purchaseToken,
            @NotBlank @Size(max = 120) String productId) {}
}
