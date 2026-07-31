package com.esquilospeak.operations;

import jakarta.validation.constraints.Min;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties("esquilospeak.rate-limit")
class RateLimitProperties {

    private boolean enabled = true;
    @Min(1)
    private int attemptsPerMinute = 60;
    @Min(1)
    private int syncPushPerMinute = 30;
    @Min(1)
    private int privacyPerHour = 5;
    @Min(1)
    private int adminWritesPerMinute = 60;
    @Min(1)
    private int advancedFeedbackPerMinute = 12;
    @Min(1)
    private int commerceWritesPerMinute = 10;
    @Min(1)
    private int supportWritesPerHour = 10;

    boolean isEnabled() {
        return enabled;
    }

    void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    int getAttemptsPerMinute() {
        return attemptsPerMinute;
    }

    void setAttemptsPerMinute(int attemptsPerMinute) {
        this.attemptsPerMinute = attemptsPerMinute;
    }

    int getSyncPushPerMinute() {
        return syncPushPerMinute;
    }

    void setSyncPushPerMinute(int syncPushPerMinute) {
        this.syncPushPerMinute = syncPushPerMinute;
    }

    int getPrivacyPerHour() {
        return privacyPerHour;
    }

    void setPrivacyPerHour(int privacyPerHour) {
        this.privacyPerHour = privacyPerHour;
    }

    int getAdminWritesPerMinute() {
        return adminWritesPerMinute;
    }

    void setAdminWritesPerMinute(int adminWritesPerMinute) {
        this.adminWritesPerMinute = adminWritesPerMinute;
    }

    int getAdvancedFeedbackPerMinute() {
        return advancedFeedbackPerMinute;
    }

    void setAdvancedFeedbackPerMinute(int advancedFeedbackPerMinute) {
        this.advancedFeedbackPerMinute = advancedFeedbackPerMinute;
    }

    int getCommerceWritesPerMinute() {
        return commerceWritesPerMinute;
    }

    void setCommerceWritesPerMinute(int commerceWritesPerMinute) {
        this.commerceWritesPerMinute = commerceWritesPerMinute;
    }

    int getSupportWritesPerHour() {
        return supportWritesPerHour;
    }

    void setSupportWritesPerHour(int supportWritesPerHour) {
        this.supportWritesPerHour = supportWritesPerHour;
    }
}
