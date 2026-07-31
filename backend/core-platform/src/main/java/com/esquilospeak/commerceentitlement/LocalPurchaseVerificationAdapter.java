package com.esquilospeak.commerceentitlement;

import com.esquilospeak.ApiException;
import java.time.Clock;
import java.time.temporal.ChronoUnit;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
@Profile("local")
public final class LocalPurchaseVerificationAdapter implements PurchaseVerificationPort {

    private final Clock clock;
    private final String productId;
    private final String entitlementCode;
    private final long durationDays;

    LocalPurchaseVerificationAdapter(
            Clock clock,
            @Value("${esquilospeak.commerce.local-product-id}") String productId,
            @Value("${esquilospeak.commerce.local-entitlement-code}") String entitlementCode,
            @Value("${esquilospeak.commerce.local-duration-days}") long durationDays) {
        this.clock = clock;
        this.productId = productId;
        this.entitlementCode = entitlementCode;
        this.durationDays = durationDays;
    }

    @Override
    public Verification verify(String purchaseToken, String productId, String eventType) {
        boolean accepted = purchaseToken.startsWith("local-test-")
                && this.productId.equals(productId)
                && ("purchase_verified".equals(eventType) || "refund_verified".equals(eventType));
        String state = "refund_verified".equals(eventType) ? "revoked" : "active";
        return new Verification(
                accepted,
                state,
                entitlementCode,
                "active".equals(state) ? clock.instant().plus(durationDays, ChronoUnit.DAYS) : null,
                "google_play");
    }
}

@Component
@Profile("!local")
final class UnavailablePurchaseVerificationAdapter implements PurchaseVerificationPort {

    @Override
    public Verification verify(String purchaseToken, String productId, String eventType) {
        throw new ApiException(
                HttpStatus.SERVICE_UNAVAILABLE,
                "PURCHASE_VERIFIER_UNAVAILABLE",
                "The production purchase verifier is not configured.",
                true,
                java.util.List.of());
    }
}
