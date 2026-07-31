package com.esquilospeak;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.core.convert.converter.Converter;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtValidators;

class SecurityConfigurationTest {

    @Test
    void validatesRequiredAudience() {
        Jwt valid = jwt(List.of("esquilospeak-mobile"));
        Jwt invalid = jwt(List.of("another-api"));

        assertFalse(SecurityConfiguration.audienceValidator("esquilospeak-mobile")
                .validate(valid)
                .hasErrors());
        assertTrue(SecurityConfiguration.audienceValidator("esquilospeak-mobile")
                .validate(invalid)
                .hasErrors());
    }

    @Test
    void mapsOnlyKnownRoles() {
        Converter<Jwt, AbstractAuthenticationToken> converter =
                new SecurityConfiguration().jwtAuthenticationConverter();
        Jwt jwt = Jwt.withTokenValue("token")
                .header("alg", "none")
                .subject("subject")
                .claim("roles", List.of("learner", "admin", "untrusted"))
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(60))
                .build();

        AbstractAuthenticationToken authentication = converter.convert(jwt);

        assertTrue(authentication.getAuthorities().stream()
                .anyMatch(authority -> authority.getAuthority().equals("ROLE_LEARNER")));
        assertTrue(authentication.getAuthorities().stream()
                .anyMatch(authority -> authority.getAuthority().equals("ROLE_ADMIN")));
        assertFalse(authentication.getAuthorities().stream()
                .anyMatch(authority -> authority.getAuthority().equals("ROLE_UNKNOWN")));
    }

    @Test
    void validatesIssuerExpirationAndScope() {
        Jwt valid = Jwt.withTokenValue("token")
                .header("alg", "none")
                .issuer("https://identity.test")
                .subject("subject")
                .claim("scope", "learning profile")
                .issuedAt(Instant.now().minusSeconds(5))
                .expiresAt(Instant.now().plusSeconds(60))
                .build();
        Jwt wrongIssuer = Jwt.withTokenValue("token")
                .header("alg", "none")
                .issuer("https://wrong-issuer.test")
                .subject("subject")
                .issuedAt(Instant.now().minusSeconds(5))
                .expiresAt(Instant.now().plusSeconds(60))
                .build();
        Jwt expired = Jwt.withTokenValue("token")
                .header("alg", "none")
                .issuer("https://identity.test")
                .subject("subject")
                .issuedAt(Instant.now().minusSeconds(600))
                .expiresAt(Instant.now().minusSeconds(300))
                .build();

        assertFalse(JwtValidators.createDefaultWithIssuer("https://identity.test")
                .validate(valid)
                .hasErrors());
        assertTrue(JwtValidators.createDefaultWithIssuer("https://identity.test")
                .validate(wrongIssuer)
                .hasErrors());
        assertTrue(JwtValidators.createDefaultWithIssuer("https://identity.test")
                .validate(expired)
                .hasErrors());

        AbstractAuthenticationToken authentication =
                new SecurityConfiguration().jwtAuthenticationConverter().convert(valid);
        assertTrue(authentication.getAuthorities().stream()
                .anyMatch(authority -> authority.getAuthority().equals("SCOPE_learning")));
        assertTrue(authentication.getAuthorities().stream()
                .anyMatch(authority -> authority.getAuthority().equals("SCOPE_profile")));
    }

    private Jwt jwt(List<String> audiences) {
        return Jwt.withTokenValue("token")
                .header("alg", "none")
                .issuer("https://identity.test")
                .subject("subject")
                .audience(audiences)
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(60))
                .build();
    }
}
