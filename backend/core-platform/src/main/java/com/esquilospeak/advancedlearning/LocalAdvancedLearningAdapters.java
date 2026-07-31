package com.esquilospeak.advancedlearning;

import com.esquilospeak.ApiException;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Locale;
import java.util.Map;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

@Component
@Profile("local")
public final class LocalAdvancedLearningAdapters
        implements MediaDeliveryPort, SpeechProviderPort, WritingConversationProviderPort {

    private static final int SAMPLE_RATE = 8_000;

    @Override
    public MediaAsset load(String mediaId) {
        byte[] wav = tone(mediaId);
        return new MediaAsset(wav, "audio/wav", sha256(wav));
    }

    @Override
    public SpeechAssessment assess(byte[] audio, String expectedText, String locale) {
        if (audio.length < 44) {
            throw new ApiException(
                    HttpStatus.UNPROCESSABLE_CONTENT,
                    "AUDIO_NOT_RECOGNIZED",
                    "The audio sample is too short to assess.");
        }
        double score = Math.min(100, 55 + Math.log10(audio.length) * 10);
        return new SpeechAssessment(
                expectedText,
                Math.round(score * 100.0) / 100.0,
                Map.of(
                        "summary", "Pronunciation sample accepted.",
                        "nextStep", "Repeat once with a steady pace.",
                        "locale", locale),
                "local-deterministic");
    }

    @Override
    public TextFeedback feedback(String kind, String input, String locale) {
        String normalized = input.toLowerCase(Locale.ROOT);
        if (normalized.contains("suicide") || normalized.contains("tự sát")) {
            return new TextFeedback(
                    Map.of("summary", "This response cannot be evaluated automatically."),
                    "blocked",
                    "local-deterministic");
        }
        int words = input.trim().split("\\s+").length;
        return new TextFeedback(
                Map.of(
                        "summary", words >= 5
                                ? "Clear response with enough detail."
                                : "Add one more complete sentence.",
                        "wordCount", words,
                        "locale", locale,
                        "mode", kind),
                "allowed",
                "local-deterministic");
    }

    private static byte[] tone(String seed) {
        int samples = SAMPLE_RATE / 4;
        ByteArrayOutputStream out = new ByteArrayOutputStream(44 + samples * 2);
        try {
            out.write("RIFF".getBytes(java.nio.charset.StandardCharsets.US_ASCII));
            writeInt(out, 36 + samples * 2);
            out.write("WAVEfmt ".getBytes(java.nio.charset.StandardCharsets.US_ASCII));
            writeInt(out, 16);
            writeShort(out, 1);
            writeShort(out, 1);
            writeInt(out, SAMPLE_RATE);
            writeInt(out, SAMPLE_RATE * 2);
            writeShort(out, 2);
            writeShort(out, 16);
            out.write("data".getBytes(java.nio.charset.StandardCharsets.US_ASCII));
            writeInt(out, samples * 2);
            int frequency = 360 + Math.floorMod(seed.hashCode(), 220);
            for (int i = 0; i < samples; i++) {
                short value = (short) (Math.sin(2 * Math.PI * frequency * i / SAMPLE_RATE) * 3_000);
                writeShort(out, value);
            }
        } catch (IOException impossible) {
            throw new IllegalStateException(impossible);
        }
        return out.toByteArray();
    }

    private static void writeInt(ByteArrayOutputStream out, int value) throws IOException {
        out.write(ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(value).array());
    }

    private static void writeShort(ByteArrayOutputStream out, int value) throws IOException {
        out.write(ByteBuffer.allocate(2).order(ByteOrder.LITTLE_ENDIAN).putShort((short) value).array());
    }

    private static String sha256(byte[] value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException(exception);
        }
    }
}

@Component
@Profile("!local")
final class UnavailableAdvancedLearningAdapters
        implements MediaDeliveryPort, SpeechProviderPort, WritingConversationProviderPort {

    @Override
    public MediaAsset load(String mediaId) {
        throw unavailable();
    }

    @Override
    public SpeechAssessment assess(byte[] audio, String expectedText, String locale) {
        throw unavailable();
    }

    @Override
    public TextFeedback feedback(String kind, String input, String locale) {
        throw unavailable();
    }

    private ApiException unavailable() {
        return new ApiException(
                HttpStatus.SERVICE_UNAVAILABLE,
                "ADVANCED_PROVIDER_UNAVAILABLE",
                "The production advanced-learning provider is not configured.",
                true,
                java.util.List.of());
    }
}
