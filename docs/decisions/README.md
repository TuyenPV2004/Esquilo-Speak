# Version-controlled project decisions

This directory is the durable source of truth for accepted architecture and
delivery decisions.

Research notes and working documents may remain local, but any decision that
changes a public contract, security/privacy behavior, module boundary, release
gate, or foundational dependency must be recorded here before implementation.

Decision status:

- `Proposed`: under review and must not be treated as committed scope.
- `Accepted`: approved and governing implementation.
- `Superseded`: replaced by a newer decision that links back to it.
- `Rejected`: considered but intentionally not adopted.

## Accepted decisions

- [`ADR-002`](ADR-002-foundation-and-first-learning-slice.md): foundation and
  first learning slice.
- [`ADR-003`](ADR-003-first-slice-closure-and-p0-gate.md): first-slice closure
  and the requirement to accept the P0 gate before identity expansion.
- [`ADR-004`](ADR-004-p0-product-privacy-and-service-decisions.md): accepted P0
  product, age, guest, consent, retention, service, and support decisions.
- [`ADR-005`](ADR-005-learning-mastery-review-offline-sync.md): learning,
  mastery, review, and offline synchronization P0.
- [`ADR-006`](ADR-006-android-application-foundation.md): Android application
  foundation, dependencies, security boundaries, and offline strategy.
- [`ADR-007`](ADR-007-closed-testing-advanced-learning-p1.md): provider-neutral
  advanced-learning P1 backend for closed testing and production fail-closed
  boundaries.
- [`ADR-008`](ADR-008-versioned-proficiency-frameworks.md): versioned,
  data-driven proficiency frameworks and course-specific placement evidence.
- [`ADR-009`](ADR-009-exercise-engine-v2-and-unit-one.md): registry-based
  Exercise Engine V2, canonical scoring/evidence and Unit 1 runtime decisions.
