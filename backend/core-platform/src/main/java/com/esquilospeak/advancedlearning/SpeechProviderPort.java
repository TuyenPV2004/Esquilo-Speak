package com.esquilospeak.advancedlearning;

import java.util.Map;

public interface SpeechProviderPort {

    SpeechAssessment assess(byte[] audio, String expectedText, String locale);

    record SpeechAssessment(
            String transcript,
            double score,
            Map<String, Object> feedback,
            String provider) {}
}
