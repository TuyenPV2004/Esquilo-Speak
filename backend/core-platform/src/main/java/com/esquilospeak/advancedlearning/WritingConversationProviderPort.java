package com.esquilospeak.advancedlearning;

import java.util.Map;

public interface WritingConversationProviderPort {

    TextFeedback feedback(String kind, String input, String locale);

    record TextFeedback(
            Map<String, Object> feedback,
            String safetyState,
            String provider) {}
}
