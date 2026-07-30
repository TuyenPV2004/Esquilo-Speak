package com.esquilospeak.learning;

import java.time.Instant;
import java.util.UUID;

public record LearningSessionChanged(
        String learnerId,
        UUID sessionId,
        UUID clientSessionId,
        String courseId,
        int contentVersion,
        String state,
        Instant changedAt) {}
