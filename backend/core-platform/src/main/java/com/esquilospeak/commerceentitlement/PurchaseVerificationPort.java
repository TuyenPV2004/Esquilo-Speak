package com.esquilospeak.commerceentitlement;

import java.time.Instant;

public interface PurchaseVerificationPort {

    Verification verify(String purchaseToken, String productId, String eventType);

    record Verification(
            boolean accepted,
            String state,
            String entitlementCode,
            Instant validUntil,
            String source) {}
}
