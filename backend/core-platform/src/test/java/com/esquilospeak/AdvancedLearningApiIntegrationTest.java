package com.esquilospeak;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.Base64;
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
class AdvancedLearningApiIntegrationTest {

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
    void streamsMediaAndPersistsOnlyDerivedPronunciationResult() throws Exception {
        String subject = "advanced-" + UUID.randomUUID();
        mockMvc.perform(get("/api/mobile/v1/media/a1-hello").with(learner(subject)))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", "audio/wav"))
                .andExpect(header().exists("ETag"));

        UUID requestId = UUID.randomUUID();
        String audio = Base64.getEncoder().encodeToString(new byte[64]);
        String body = """
                {
                  "clientRequestId": "%s",
                  "audioBase64": "%s",
                  "expectedText": "hello",
                  "locale": "en"
                }
                """.formatted(requestId, audio);
        mockMvc.perform(post("/api/mobile/v1/advanced/pronunciation")
                        .with(learner(subject))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.kind").value("pronunciation"))
                .andExpect(jsonPath("$.score").isNumber())
                .andExpect(jsonPath("$.provider").value("local-deterministic"));
        mockMvc.perform(post("/api/mobile/v1/advanced/pronunciation")
                        .with(learner(subject))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk());

        long rows = jdbc.sql("""
                        select count(*) from advanced_feedback_results
                        where client_request_id = :requestId and input_text is null
                        """)
                .param("requestId", requestId)
                .query(Long.class)
                .single();
        org.junit.jupiter.api.Assertions.assertEquals(1, rows);
    }

    @Test
    void returnsSafetyFilteredWritingFeedback() throws Exception {
        mockMvc.perform(post("/api/mobile/v1/advanced/writing")
                        .with(learner("writer-" + UUID.randomUUID()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "clientRequestId": "%s",
                                  "contentRef": "lesson-basic-greetings",
                                  "input": "Hello, my name is Ana.",
                                  "locale": "en"
                                }
                                """.formatted(UUID.randomUUID())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.feedback.code").value("writing.clearResponse"))
                .andExpect(jsonPath("$.feedback.parameters.wordCount").value(5));
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
}
