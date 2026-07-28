package com.esquilospeak;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.oauth2.jwt.JwtDecoders;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
class SecurityConfiguration {

    @Bean
    SecurityFilterChain apiSecurity(HttpSecurity http) throws Exception {
        return http.csrf(csrf -> csrf.disable())
                .authorizeHttpRequests(authorize -> authorize
                        .requestMatchers(
                                "/actuator/health/**",
                                "/api/mobile/v1/languages",
                                "/api/mobile/v1/courses",
                                "/api/mobile/v1/courses/*/lessons",
                                "/api/mobile/v1/lessons/*",
                                "/internal/dev/token")
                        .permitAll()
                        .anyRequest()
                        .authenticated())
                .oauth2ResourceServer(resourceServer -> resourceServer.jwt(Customizer.withDefaults()))
                .build();
    }

    @Bean
    @Profile("production")
    JwtDecoder productionJwtDecoder(org.springframework.core.env.Environment environment) {
        String issuer = environment.getRequiredProperty("ESQUILO_JWT_ISSUER_URI");
        return JwtDecoders.fromIssuerLocation(issuer);
    }
}
