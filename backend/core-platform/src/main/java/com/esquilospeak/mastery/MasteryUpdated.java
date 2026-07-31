package com.esquilospeak.mastery;

import java.time.Instant;
import java.util.UUID;

public record MasteryUpdated(
        String learnerId,
        UUID attemptId,
        String conceptId,
        int modelVersion,
        double score,
        int correctEvidenceCount,
        int evidenceCount,
        boolean latestCorrect,
        Instant updatedAt) {}
