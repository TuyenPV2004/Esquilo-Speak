# ADR-003 — Close the first learning slice before P0 expansion

- Status: Accepted
- Date: 2026-07-30
- Scope: Android-first delivery, first learning vertical slice, P0 gate

## Context

The repository implements catalog, lesson delivery, multiple-choice attempts,
feedback, and progress. Backend idempotency exists, but the mobile client
previously generated new mutation identifiers for every HTTP call. The slice
also lacked an Android-to-backend-to-PostgreSQL automated test and an OpenAPI
compatibility gate.

Product decisions that affect identity, consent, content, and privacy are not
yet accepted. Starting those modules before the decisions are locked would
create avoidable contract and data-model rework.

## Decision

1. Complete the first slice before adding a new P0 business module.
2. Represent one logical attempt with stable `clientAttemptId`,
   `Idempotency-Key`, payload, and occurrence time across retries.
3. Keep the pending mutation in memory for the current slice. Durable outbox
   persistence is part of the offline application foundation and must be
   selected only after its storage requirements are accepted.
4. Run the live learning journey on an Android emulator against the Spring
   backend and PostgreSQL in CI.
5. Compare OpenAPI changes against the pull request base and fail on breaking
   changes at warning severity or above.
6. Keep accepted ADRs and the P0 gate in version control even when research
   documents remain local.
7. Do not begin production identity implementation until the open P0 product
   and privacy decisions are accepted.
8. Establish OpenAPI `0.4.0` as the first compatibility baseline. The `0.1.0`
   document on the target branch predates this gate, was not a released
   contract, and exposed scoring fields in the learner response. The bootstrap
   pull request compares its active contract with the immutable `0.4.0`
   release artifact; every later pull request compares directly with its target
   branch.

## Consequences

- Retry within the same app process is deduplicated end to end.
- App termination can still lose a pending mutation until the durable outbox is
  implemented.
- CI becomes slower because one job boots PostgreSQL, the backend, and an
  Android emulator.
- Contract changes require an explicit compatibility review.
- The one-time bootstrap is explicit and reviewable; it does not add an
  oasdiff ignore rule or weaken compatibility checks after the gate lands.
- Identity/profile implementation remains blocked by product decisions, not by
  missing technical scaffolding.
