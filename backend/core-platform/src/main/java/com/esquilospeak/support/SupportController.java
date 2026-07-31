package com.esquilospeak.support;

import com.esquilospeak.identityprofile.IdentityProfileService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
class SupportController {

    private final SupportService service;
    private final IdentityProfileService identities;

    SupportController(SupportService service, IdentityProfileService identities) {
        this.service = service;
        this.identities = identities;
    }

    @PostMapping("/api/mobile/v1/support/tickets")
    SupportService.Ticket create(
            @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody TicketBody body) {
        UUID learnerId = identities.requireLearningAccess(jwt).learnerId();
        return service.create(
                learnerId,
                body.type(),
                body.contentRef(),
                body.locale(),
                body.description());
    }

    @GetMapping("/api/mobile/v1/support/tickets")
    List<SupportService.Ticket> list(@AuthenticationPrincipal Jwt jwt) {
        return service.list(identities.requireLearningAccess(jwt).learnerId());
    }

    @PatchMapping("/api/support/v1/tickets/{ticketId}/status")
    SupportService.Ticket updateStatus(
            @PathVariable UUID ticketId, @Valid @RequestBody StatusBody body) {
        return service.updateStatus(ticketId, body.status());
    }

    record TicketBody(
            @NotBlank @Pattern(regexp = "support|content_report") String type,
            @Size(max = 160) String contentRef,
            @NotBlank @Size(max = 35) String locale,
            @NotBlank @Size(max = 2000) String description) {}

    record StatusBody(
            @NotBlank @Pattern(regexp = "triaged|resolved|dismissed") String status) {}
}
