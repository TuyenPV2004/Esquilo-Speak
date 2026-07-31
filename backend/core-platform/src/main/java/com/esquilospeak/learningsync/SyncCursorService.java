package com.esquilospeak.learningsync;

import com.esquilospeak.ApiException;
import com.esquilospeak.learning.LearningSyncCursorProvider;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

@Service
class SyncCursorService implements LearningSyncCursorProvider {

    private final JdbcClient jdbc;

    SyncCursorService(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public String currentCursor(String learnerId) {
        return encode(currentSequence(learnerId));
    }

    long currentSequence(String learnerId) {
        Long value = jdbc.sql("""
                        select coalesce(max(sequence_id), 0)
                        from sync_changes
                        where learner_id = :learnerId
                        """)
                .param("learnerId", learnerId)
                .query(Long.class)
                .single();
        return value == null ? 0 : value;
    }

    String encode(long sequence) {
        return "v1." + Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(Long.toString(sequence).getBytes(StandardCharsets.UTF_8));
    }

    long decode(String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return 0;
        }
        try {
            if (!cursor.startsWith("v1.")) {
                throw new IllegalArgumentException();
            }
            String value = new String(
                    Base64.getUrlDecoder().decode(cursor.substring(3)), StandardCharsets.UTF_8);
            long sequence = Long.parseLong(value);
            if (sequence < 0) {
                throw new IllegalArgumentException();
            }
            return sequence;
        } catch (IllegalArgumentException exception) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "SYNC_CURSOR_INVALID",
                    "The sync cursor is invalid or belongs to an unsupported version.");
        }
    }

    void ensureNotAhead(long sequence, long current) {
        if (sequence > current) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "SYNC_CURSOR_AHEAD",
                    "The sync cursor is ahead of this learner's canonical change sequence.");
        }
    }
}
