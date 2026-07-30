package com.esquilospeak.reviewscheduler;

import java.time.Instant;

public record ReviewScheduled(
        String learnerId,
        String conceptId,
        int modelVersion,
        Instant dueAt,
        int intervalDays,
        int repetitions,
        String lastResult,
        Instant updatedAt) {}
