package com.esquilospeak.identityprofile;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(
        name = "esquilospeak.privacy.processor-enabled",
        havingValue = "true",
        matchIfMissing = true)
class PrivacyRequestProcessor {

    private final PrivacyRequestService privacyRequestService;

    PrivacyRequestProcessor(PrivacyRequestService privacyRequestService) {
        this.privacyRequestService = privacyRequestService;
    }

    @Scheduled(fixedDelayString = "${esquilospeak.privacy.processing-delay:5000}")
    void processPendingRequest() {
        privacyRequestService.requestNextInactiveGuestDeletion();
        privacyRequestService.processNext();
    }
}
