package com.esquilospeak.curriculumcontent;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(
        name = "esquilospeak.content.publisher-enabled",
        havingValue = "true",
        matchIfMissing = true)
class ContentPublishingProcessor {

    private final CurriculumContentAdminService contentAdminService;

    ContentPublishingProcessor(CurriculumContentAdminService contentAdminService) {
        this.contentAdminService = contentAdminService;
    }

    @Scheduled(fixedDelayString = "${esquilospeak.content.publishing-delay:5000}")
    void publishDueVersion() {
        contentAdminService.publishNextDueVersion();
    }
}
