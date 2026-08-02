package com.esquilospeak.productquality;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
class AnalyticsRetentionProcessor {

    private final ProductQualityService service;
    private final boolean enabled;

    AnalyticsRetentionProcessor(
            ProductQualityService service,
            @Value("${esquilospeak.analytics.retention-enabled:true}") boolean enabled) {
        this.service = service;
        this.enabled = enabled;
    }

    @Scheduled(cron = "0 30 3 * * *", zone = "UTC")
    void purgeExpiredEvents() {
        if (enabled) {
            service.purgeExpired();
        }
    }
}
