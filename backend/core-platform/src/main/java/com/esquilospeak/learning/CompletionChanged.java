package com.esquilospeak.learning;

import java.time.Instant;

public record CompletionChanged(
        String learnerId,
        String courseId,
        String lessonId,
        int lessonVersion,
        boolean completed,
        Instant changedAt) {}
