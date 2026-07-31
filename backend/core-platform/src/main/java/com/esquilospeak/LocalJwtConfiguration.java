package com.esquilospeak;

import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.source.ImmutableJWKSet;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

@Configuration
@Profile("local")
class LocalJwtConfiguration {

    @Bean
    RSAKey localRsaKey() throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
        generator.initialize(2048);
        KeyPair pair = generator.generateKeyPair();
        return new RSAKey.Builder((RSAPublicKey) pair.getPublic())
                .privateKey((RSAPrivateKey) pair.getPrivate())
                .keyID(UUID.randomUUID().toString())
                .build();
    }

    @Bean
    JwtDecoder localJwtDecoder(
            RSAKey key,
            org.springframework.core.env.Environment environment)
            throws Exception {
        String issuer = "http://localhost:8080";
        String audience =
                environment.getProperty("ESQUILO_JWT_AUDIENCE", "esquilospeak-mobile");
        NimbusJwtDecoder decoder = NimbusJwtDecoder.withPublicKey(key.toRSAPublicKey())
                .signatureAlgorithm(SignatureAlgorithm.RS256)
                .build();
        decoder.setJwtValidator(new org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator<>(
                JwtValidators.createDefaultWithIssuer(issuer),
                SecurityConfiguration.audienceValidator(audience)));
        return decoder;
    }

    @Bean
    JwtEncoder localJwtEncoder(RSAKey key) {
        return new NimbusJwtEncoder(new ImmutableJWKSet<>(new JWKSet(key)));
    }

}

@RestController
@Profile("local")
class LocalTokenController {

    private final JwtEncoder encoder;
    private final Clock clock;
    private final String audience;

    LocalTokenController(
            JwtEncoder encoder,
            Clock clock,
            org.springframework.core.env.Environment environment) {
        this.encoder = encoder;
        this.clock = clock;
        this.audience =
                environment.getProperty("ESQUILO_JWT_AUDIENCE", "esquilospeak-mobile");
    }

    @PostMapping("/internal/dev/token")
    Map<String, Object> token() {
        Instant now = clock.instant();
        Instant expiresAt = now.plus(8, ChronoUnit.HOURS);
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer("http://localhost:8080")
                .subject("local-guest-" + UUID.randomUUID())
                .audience(List.of(audience))
                .issuedAt(now)
                .expiresAt(expiresAt)
                .claim("scope", "learning")
                .claim("roles", List.of("learner"))
                .claim("actor_type", "guest")
                .build();
        String token = encoder.encode(JwtEncoderParameters.from(claims)).getTokenValue();
        return Map.of("accessToken", token, "expiresAt", expiresAt);
    }
}
