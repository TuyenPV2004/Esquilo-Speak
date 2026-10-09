# ADR-011: Closed-beta evidence and Product Completion Gate

- Status: Accepted
- Date: 2026-08-02
- Decision owners: Product, support, privacy, backend, Android
- Scope: Giai đoạn 9 of `docs/plans/Ke_Hoach_2.md`
- Depends on: ADR-010 product-quality metrics and consent boundary

## Context

The English A1 product has the technical course, exercise engine, daily loop,
practice modes and product-quality read model required to begin closed beta.
Automated tests prove implementation properties but cannot prove user acceptance,
retention, physical-device microphone behavior or a release decision. The project
needs one versioned evidence contract that prevents synthetic data or feature count
from unlocking Android release readiness.

Support status alone also cannot govern P0/P1 beta findings. A serious finding needs
severity, an accountable pseudonymous owner, an action plan, a release decision and
proof that the response loop with the tester was closed.

## Decision

1. `closed-beta-v1` targets Vietnamese-speaking adults learning English A1. The
   operational baseline is at least 20 consented learners, at least 15 matured D7
   learners and a 14-day observation window. This is a product-decision baseline,
   not a statistically powered efficacy claim.
2. Beta participation consent is versioned separately from optional
   `operational_telemetry`. Refusing telemetry does not block learning. The repository
   stores only aggregate evidence and pseudonymous device/participant references.
3. In-app Support is the canonical feedback/withdrawal channel. Qualitative review
   must cover onboarding, learning path, lesson, daily loop and feedback; raw interview
   text and personal/contact data stay outside Git.
4. Device evidence requires three supported Android API-level buckets, two physical
   device models, two physical microphone passes and at least one offline/reconnect
   journey. Emulator evidence may supplement but cannot replace physical evidence.
5. Support operations receives a separate representation and triage mutation with
   P0/P1/P2 severity, owner reference, action plan, release decision, resolution
   summary and confirmed tester-loop state. Each mutation creates an immutable event
   with a SHA-256 actor hash. Learner responses do not expose these internal fields.
6. P0 findings cannot be accepted for release with a plan. Resolved or dismissed
   findings require a summary and confirmed tester loop. The legacy status-only
   operation remains temporarily for compatibility but cannot close a beta P0/P1.
7. Completion evaluation fails closed. It requires matured cohort metrics with source
   and sample size, the device matrix, aggregate feedback, zero open P0, complete P1
   ownership/decision, all rehearsals, product gates and role-based product
   owner/developer sign-off.
8. Giai đoạn 13 remains locked until the evaluator passes and the developer explicitly
   records the unlock decision. Approval to implement this framework is not that
   sign-off.

## Consequences

- Technical readiness and product completion are reported separately; an empty cohort
  cannot produce a green gate.
- Beta coordination has a minimum 14-day lead time and physical-device requirement.
- Support stores additional internal free text; it remains covered by account export/
  deletion and must not contain secrets or unnecessary personal data.
- The initial cohort size is deliberately modest and should be revisited after V1 if
  the product needs statistically powered experiments or segmented efficacy claims.

## Verification

- `Closed_Beta_Contract_Test.mjs` validates the cohort, consent, feedback, SLA,
  privacy and device evidence contract.
- `Evaluate_Closed_Beta_Gate.mjs` returns a non-zero result until one real evidence
  bundle satisfies every gate.
- `CommerceSupportApiIntegrationTest` verifies authority separation, P0 policy,
  internal-field non-disclosure, resolution/closed-loop state and hashed audit events.
- `IdentityProfileApiIntegrationTest` and `OperationsApiIntegrationTest` rehearse
  privacy export/delete and PostgreSQL backup/restore.
