package com.esquilospeak;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@Testcontainers
@SpringBootTest(properties = {
    "esquilospeak.privacy.processor-enabled=false",
    "esquilospeak.content.publisher-enabled=false"
})
@AutoConfigureMockMvc
class CommerceSupportApiIntegrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer(DockerImageName.parse("postgres:18-alpine"));

    @DynamicPropertySource
    static void databaseProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @Autowired MockMvc mockMvc;
    @Autowired JdbcClient jdbc;

    @Test
    void grantsAndRevokesPremiumWithoutPersistingRawPurchaseToken() throws Exception {
        RequestPostProcessor learner = learner("commerce-" + UUID.randomUUID());
        String token = "local-test-" + UUID.randomUUID();
        String body = """
                {"purchaseToken":"%s","productId":"premium-monthly"}
                """.formatted(token);
        mockMvc.perform(post("/api/mobile/v1/commerce/purchases/verify")
                        .with(learner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value("premium"))
                .andExpect(jsonPath("$.status").value("active"));
        mockMvc.perform(post("/api/mobile/v1/commerce/purchases/refund")
                        .with(learner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("revoked"));
        mockMvc.perform(post("/api/mobile/v1/commerce/purchases/verify")
                        .with(learner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("revoked"));
        mockMvc.perform(post("/api/mobile/v1/commerce/purchases/refund")
                        .with(learner("other-" + UUID.randomUUID()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("PURCHASE_ALREADY_CLAIMED"));
        long leaked = jdbc.sql("""
                        select count(*) from purchase_events
                        where purchase_token_hash = :rawToken
                        """)
                .param("rawToken", token)
                .query(Long.class)
                .single();
        org.junit.jupiter.api.Assertions.assertEquals(0, leaked);
    }

    @Test
    void createsContentReportAndAllowsSupportTriage() throws Exception {
        RequestPostProcessor learner = learner("support-" + UUID.randomUUID());
        String created = mockMvc.perform(post("/api/mobile/v1/support/tickets")
                        .with(learner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "type":"content_report",
                                  "contentRef":"lesson-basic-greetings",
                                  "locale":"vi",
                                  "description":"Nội dung cần được kiểm tra."
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("open"))
                .andReturn().getResponse().getContentAsString();
        String ticketId = field(created, "id");
        mockMvc.perform(patch("/api/support/v1/tickets/{ticketId}/status", ticketId)
                        .with(supportStaff())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"triaged\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("triaged"));
        mockMvc.perform(get("/api/mobile/v1/support/tickets").with(learner))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].status").value("triaged"));
    }

    private RequestPostProcessor learner(String subject) {
        return jwt()
                .jwt(token -> token.issuer("https://identity.test")
                        .subject(subject)
                        .claim("scope", "learning")
                        .claim("actor_type", "guest")
                        .claim("roles", java.util.List.of("learner")))
                .authorities(
                        new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_LEARNER"),
                        new org.springframework.security.core.authority.SimpleGrantedAuthority("SCOPE_learning"));
    }

    private RequestPostProcessor supportStaff() {
        return jwt().authorities(
                new org.springframework.security.core.authority.SimpleGrantedAuthority("ROLE_SUPPORT"),
                new org.springframework.security.core.authority.SimpleGrantedAuthority("SCOPE_operations"));
    }

    private String field(String json, String name) {
        String prefix = "\"" + name + "\":\"";
        int start = json.indexOf(prefix) + prefix.length();
        return json.substring(start, json.indexOf('"', start));
    }
}
