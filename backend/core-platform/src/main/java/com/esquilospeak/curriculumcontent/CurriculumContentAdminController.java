package com.esquilospeak.curriculumcontent;

import com.esquilospeak.curriculumcontent.CurriculumContentAdminService.ContentTransition;
import com.esquilospeak.curriculumcontent.CurriculumContentAdminService.ContentVersion;
import com.esquilospeak.curriculumcontent.CurriculumContentAdminService.CourseVersionDraft;
import com.esquilospeak.curriculumcontent.CurriculumContentAdminService.ReviewEvidence;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import java.time.Instant;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping("/api/admin/v1/content/courses")
class CurriculumContentAdminController {

    private static final String IDENTIFIER = "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$";

    private final CurriculumContentAdminService contentAdminService;

    CurriculumContentAdminController(CurriculumContentAdminService contentAdminService) {
        this.contentAdminService = contentAdminService;
    }

    @PutMapping("/{courseId}/versions/{version}")
    @ResponseStatus(HttpStatus.CREATED)
    ContentVersion saveDraft(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable @Pattern(regexp = IDENTIFIER) String courseId,
            @PathVariable @Min(1) int version,
            @Valid @NotNull @RequestBody CourseVersionDraft draft) {
        return contentAdminService.saveDraft(jwt, courseId, version, draft);
    }

    @GetMapping("/{courseId}/versions/{version}")
    ContentVersion authoringVersion(
            @PathVariable @Pattern(regexp = IDENTIFIER) String courseId,
            @PathVariable @Min(1) int version) {
        return contentAdminService.authoringVersion(courseId, version);
    }

    @PostMapping("/{courseId}/versions/{version}/transitions")
    ContentVersion transition(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable @Pattern(regexp = IDENTIFIER) String courseId,
            @PathVariable @Min(1) int version,
            @Valid @RequestBody TransitionBody body) {
        return contentAdminService.transition(
                jwt,
                courseId,
                version,
                new ContentTransition(body.targetState(), body.effectiveAt(), body.reviewEvidence()));
    }

    @PostMapping("/{courseId}/rollbacks")
    ContentVersion rollback(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable @Pattern(regexp = IDENTIFIER) String courseId,
            @Valid @RequestBody RollbackBody body) {
        return contentAdminService.rollback(jwt, courseId, body.targetVersion());
    }

    record TransitionBody(
            @NotBlank
                    @Pattern(regexp = "^(draft|review|approved|scheduled|published|retired)$")
                    String targetState,
            Instant effectiveAt,
            ReviewEvidence reviewEvidence) {}

    record RollbackBody(@Min(1) int targetVersion) {}
}
