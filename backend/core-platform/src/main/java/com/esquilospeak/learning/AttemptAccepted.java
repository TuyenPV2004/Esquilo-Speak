package com.esquilospeak.learning;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record AttemptAccepted(
        UUID attemptId,
        String learnerId,
        UUID clientAttemptId,
        String courseId,
        String lessonId,
        int lessonVersion,
        String exerciseId,
        List<String> conceptIds,
        boolean correct,
        Instant acceptedAt) {}
