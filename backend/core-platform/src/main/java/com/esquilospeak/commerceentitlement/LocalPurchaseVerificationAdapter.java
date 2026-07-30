package com.esquilospeak.commerceentitlement;

import com.esquilospeak.ApiException;
import java.time.Clock;
import java.time.temporal.ChronoUnit;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

@Component
@Profile("local")
public final class LocalPurchaseVerificationAdapter implements PurchaseVerificationPort {

    private final Clock clock;

    LocalPurchaseVerificationAdapter(Clock clock) {
        this.clock = clock;
    }

    @Override
    public Verification verify(String purchaseToken, String productId, String eventType) {
        boolean accepted = purchaseToken.startsWith("local-test-")
                && ("purchase_verified".equals(eventType) || "refund_verified".equals(eventType));
        String state = "refund_verified".equals(eventType) ? "revoked" : "active";
        return new Verification(
                accepted,
                state,
                "premium",
                "active".equals(state) ? clock.instant().plus(30, ChronoUnit.DAYS) : null,
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
