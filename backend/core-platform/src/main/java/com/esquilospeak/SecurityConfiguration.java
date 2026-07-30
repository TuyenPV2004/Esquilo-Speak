package com.esquilospeak;

import static org.springframework.security.authorization.AuthorizationManagers.allOf;
import static org.springframework.security.authorization.AuthorizationManagers.anyOf;
import static org.springframework.security.authorization.AuthorityAuthorizationManager.hasAuthority;
import static org.springframework.security.authorization.AuthorityAuthorizationManager.hasRole;

import com.esquilospeak.operations.SecurityFailureHandler;
import java.time.Clock;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Locale;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.core.convert.converter.Converter;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtDecoders;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableMethodSecurity
class SecurityConfiguration {

    @Bean
    SecurityFilterChain apiSecurity(
            HttpSecurity http,
            Converter<Jwt, AbstractAuthenticationToken> jwtAuthenticationConverter,
            SecurityFailureHandler securityFailureHandler)
            throws Exception {
        return http.csrf(csrf -> csrf.disable())
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(authorize -> authorize
                        .requestMatchers(
                                "/actuator/health/**",
                                "/livez",
                                "/readyz",
                                "/api/mobile/v1/languages",
                                "/api/mobile/v1/courses",
                                "/api/mobile/v1/courses/*/lessons",
                                "/api/mobile/v1/lessons/*",
                                "/internal/dev/token")
                        .permitAll()
                        .requestMatchers("/actuator/prometheus")
                        .access(allOf(
                                hasAuthority("SCOPE_operations"),
                                anyOf(hasRole("SUPPORT"), hasRole("ADMIN"))))
                        .requestMatchers("/api/mobile/v1/**")
                        .access(allOf(hasRole("LEARNER"), hasAuthority("SCOPE_learning")))
                        .requestMatchers("/api/admin/v1/content/**")
                        .access(allOf(
                                hasAuthority("SCOPE_content"),
                                anyOf(hasRole("CONTENT_STAFF"), hasRole("ADMIN"))))
                        .anyRequest()
                        .authenticated())
                .oauth2ResourceServer(resourceServer -> resourceServer.jwt(jwt ->
                        jwt.jwtAuthenticationConverter(jwtAuthenticationConverter)))
                .exceptionHandling(exceptions -> exceptions
                        .authenticationEntryPoint(securityFailureHandler)
                        .accessDeniedHandler(securityFailureHandler))
                .build();
    }

    @Bean
    @Profile("production")
    JwtDecoder productionJwtDecoder(org.springframework.core.env.Environment environment) {
        String issuer = environment.getRequiredProperty("ESQUILO_JWT_ISSUER_URI");
        String audience = environment.getRequiredProperty("ESQUILO_JWT_AUDIENCE");
        NimbusJwtDecoder decoder = (NimbusJwtDecoder) JwtDecoders.fromIssuerLocation(issuer);
        decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
                JwtValidators.createDefaultWithIssuer(issuer),
                audienceValidator(audience)));
        return decoder;
    }

    @Bean
    Converter<Jwt, AbstractAuthenticationToken> jwtAuthenticationConverter() {
        JwtGrantedAuthoritiesConverter scopeConverter = new JwtGrantedAuthoritiesConverter();
        JwtAuthenticationConverter authenticationConverter = new JwtAuthenticationConverter();
        authenticationConverter.setJwtGrantedAuthoritiesConverter(jwt -> {
            Collection<GrantedAuthority> authorities =
                    new ArrayList<>(scopeConverter.convert(jwt));
            Object rolesClaim = jwt.getClaims().get("roles");
            if (rolesClaim instanceof Collection<?> roles) {
                roles.stream()
                        .filter(String.class::isInstance)
                        .map(String.class::cast)
                        .map(SecurityConfiguration::roleAuthority)
                        .filter(java.util.Objects::nonNull)
                        .forEach(authorities::add);
            } else if (rolesClaim instanceof String role) {
                GrantedAuthority authority = roleAuthority(role);
                if (authority != null) {
                    authorities.add(authority);
                }
            }
            return authorities;
        });
        return authenticationConverter;
    }

    @Bean
    Clock applicationClock() {
        return Clock.systemUTC();
    }

    static OAuth2TokenValidator<Jwt> audienceValidator(String requiredAudience) {
        return token -> token.getAudience().contains(requiredAudience)
                ? OAuth2TokenValidatorResult.success()
                : OAuth2TokenValidatorResult.failure(new OAuth2Error(
                        "invalid_token",
                        "The required audience is missing.",
                        null));
    }

    private static GrantedAuthority roleAuthority(String role) {
        String normalized = role.trim().toUpperCase(Locale.ROOT);
        return switch (normalized) {
            case "LEARNER", "CONTENT_STAFF", "SUPPORT", "ADMIN" ->
                new SimpleGrantedAuthority("ROLE_" + normalized);
            default -> null;
        };
    }
}
