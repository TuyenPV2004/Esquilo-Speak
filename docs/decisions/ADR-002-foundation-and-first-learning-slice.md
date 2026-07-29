# ADR-002 — Foundation and first learning slice

- Status: Accepted
- Accepted: 2026-07-28
- Recorded in version control: 2026-07-30

## Context

EsquiloSpeak needed an executable foundation that could validate the proposed
mobile, backend, data, contract, security, and module boundaries before the
product expanded into identity, mastery, offline sync, speech, or commerce.

The first slice had to prove a learner-safe journey without exposing answer
data before an attempt.

## Decision

1. Use Flutter for the learner application, with Android as the current release
   target.
2. Use Java 21, Spring Boot, and Spring Modulith for one modular-monolith
   backend deployable.
3. Use PostgreSQL as the transactional source of truth and Flyway for schema
   migration.
4. Use REST/JSON with OpenAPI 3.1.1 for the mobile boundary and JSON Schema
   2020-12 for content and learner-delivery documents.
5. Implement the first vertical slice as:

   `language/course catalog → lesson → multiple-choice attempt → immediate feedback → course progress`

6. Keep authoring answers and explanations out of learner lesson delivery.
7. Store attempts append-only and deduplicate by learner plus
   `clientAttemptId` or `Idempotency-Key`.
8. Use an ephemeral local JWT issuer only in the `local` profile. Production
   identity must use an external issuer.
9. Verify module boundaries with Spring Modulith and persistence behavior with
   PostgreSQL Testcontainers.
10. Do not add Redis, a message broker, Kubernetes, microservices, speech/AI,
    mastery scheduling, or subscription infrastructure to this slice.

## Consequences

- The repository has one executable path through mobile, backend, and database.
- The initial content model and API are intentionally narrow.
- Local identity is suitable only for development and end-to-end validation.
- Offline persistence, account lifecycle, content publishing, mastery, review,
  and production operations require later accepted decisions.

## Evidence

- API contract:
  `contracts/openapi/esquilospeak-learning-v1.yaml`
- Content and delivery schemas: `contracts/schema/`
- Backend integration tests:
  `backend/core-platform/src/test/java/com/esquilospeak/LearningApiIntegrationTest.java`
- Flutter journey:
  `apps/mobile/lib/features/learning/`
- Follow-up closure decision:
  `docs/decisions/ADR-003-first-slice-closure-and-p0-gate.md`
