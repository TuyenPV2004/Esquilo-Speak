package com.esquilospeak.advancedlearning;

import com.esquilospeak.ApiException;
import com.esquilospeak.identityprofile.IdentityProfileService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.Base64;
import java.util.UUID;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/mobile/v1")
class AdvancedLearningController {

    private static final String IDENTIFIER = "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$";

    private final AdvancedLearningService service;
    private final IdentityProfileService identities;

    AdvancedLearningController(AdvancedLearningService service, IdentityProfileService identities) {
        this.service = service;
        this.identities = identities;
    }

    @GetMapping("/media/{mediaId}")
    ResponseEntity<byte[]> media(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable @Pattern(regexp = IDENTIFIER) String mediaId) {
        identities.requireLearningAccess(jwt);
        MediaDeliveryPort.MediaAsset asset = service.media(mediaId);
        return ResponseEntity.ok()
                .cacheControl(CacheControl.noCache())
                .header(HttpHeaders.ETAG, "\"" + asset.checksum() + "\"")
                .header("X-Content-Type-Options", "nosniff")
                .header(HttpHeaders.CONTENT_TYPE, asset.contentType())
                .body(asset.bytes());
    }

    @PostMapping("/advanced/pronunciation")
    AdvancedLearningService.FeedbackResult pronunciation(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody PronunciationBody body) {
        UUID learnerId = identities.requireLearningAccess(jwt).learnerId();
        byte[] audio;
        try {
            audio = Base64.getDecoder().decode(body.audioBase64());
        } catch (IllegalArgumentException exception) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "INVALID_AUDIO_ENCODING",
                    "audioBase64 must contain valid Base64 data.");
        }
        return service.assessPronunciation(
                learnerId, body.clientRequestId(), audio, body.expectedText(), body.locale());
    }

    @PostMapping("/advanced/writing")
    AdvancedLearningService.FeedbackResult writing(
            @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody TextFeedbackBody body) {
        return textFeedback(jwt, body, "writing");
    }

    @PostMapping("/advanced/conversation")
    AdvancedLearningService.FeedbackResult conversation(
            @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody TextFeedbackBody body) {
        return textFeedback(jwt, body, "conversation");
    }

    private AdvancedLearningService.FeedbackResult textFeedback(
            Jwt jwt, TextFeedbackBody body, String kind) {
        UUID learnerId = identities.requireLearningAccess(jwt).learnerId();
        return service.assessText(
                learnerId,
                body.clientRequestId(),
                kind,
                body.contentRef(),
                body.input(),
                body.locale());
    }

    record PronunciationBody(
            @NotNull UUID clientRequestId,
            @NotBlank @Size(max = 2_700_000) String audioBase64,
            @NotBlank @Size(max = 500) String expectedText,
            @NotBlank @Size(max = 35) String locale) {}

    record TextFeedbackBody(
            @NotNull UUID clientRequestId,
            @NotBlank @Size(max = 160) String contentRef,
            @NotBlank @Size(max = 4000) String input,
            @NotBlank @Size(max = 35) String locale) {}
}
