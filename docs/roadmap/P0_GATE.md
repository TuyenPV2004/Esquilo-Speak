# P0 decision and delivery gate

- Status: In progress
- Started: 2026-07-30
- Target client: Android

This file is the version-controlled execution gate for Sprint B / Phase 4. An
item marked `Needs owner decision` is not accepted product scope.

## Decisions requiring product-owner approval

| ID | Decision | Current state |
| --- | --- | --- |
| P0-01 | First market and launch countries | Needs owner decision |
| P0-02 | First source and target language pair | Needs owner decision |
| P0-03 | Minimum age and whether minors are in scope | Needs owner decision |
| P0-04 | Guest lifetime, account creation, and guest-account merge | Needs owner decision |
| P0-05 | Consent model and voice/audio retention | Needs owner decision |
| P0-06 | Account export/deletion response targets and retention exceptions | Needs owner decision |
| P0-07 | P0 subscription scope | Needs owner decision |
| P0-08 | Initial learning outcome, product success metrics, and SLO | Needs owner decision |
| P0-09 | Support channels and response policy | Needs owner decision |

No default in this table may be inferred from seed data or local development
behavior.

## Capability map

| Capability | Priority | Release expectation |
| --- | --- | --- |
| Identity, guest session, profile, locale, goal, consent | P0 | Backend and Android |
| Language/course catalog and published lesson delivery | P0 | Existing slice; harden |
| Multiple-choice attempt, feedback, and progress | P0 | Existing slice; harden |
| Content versioning, publish, retire, and rollback | P0 | Backend before Android integration |
| Durable pending-attempt outbox and reconnect sync | P0 | Backend contract then Android |
| Mastery evidence and review queue | P0 | Backend contract then Android |
| Structured logs, traces, readiness, backup/restore | P0 | Before release gate |
| Listening and pronunciation | P1 | After stable P0 |
| AI writing/conversation feedback | P1 | After provider, safety, and cost gates |
| Subscription and entitlement | P1 unless P0-07 promotes it | Requires owner decision |
| Organization/class, community, certification | P2 | Evidence-driven |
| Broker, Redis, Kubernetes, independent services | P2 | Only after measured need |

## Logical ownership

| Area | Owns | Must not own |
| --- | --- | --- |
| `identity-profile` | subject mapping, learner profile, consent, preferences | course content, attempts |
| `curriculum-content` | language/course/unit/lesson/exercise versions and publishing | learner progress |
| `learning-session` | accepted attempts, scoring orchestration, completion evidence | identity credentials |
| `mastery` | mastery evidence and calculation version | content authoring |
| `review-scheduler` | due dates and review queue | attempt persistence |

Cross-module calls use public application APIs or events. Modules must not read
another module's internal repository or tables directly.

## Boundary standards

- Errors use `application/problem+json`, stable uppercase `code`, actual
  correlation `traceId`, `retryable`, and field violations when applicable.
- Important/offline mutations carry a stable client mutation ID and
  idempotency key generated once per logical action.
- Cursor pagination is required for unbounded or frequently changing
  collections. Small immutable lesson structures may remain unpaginated.
- Public API changes start in OpenAPI and pass compatibility review.
- Logs and traces must not contain access tokens, raw voice, or unnecessary
  personal data.

## Privacy inventory to complete after owner decisions

| Data class | Purpose | Initial retention position |
| --- | --- | --- |
| Identity subject mapping | authenticate and merge accounts | Until account deletion plus required audit window |
| Learner profile/preferences | personalize learning | Until account deletion |
| Attempt and progress history | learning continuity and outcome | Needs P0-06 decision |
| Consent and age-gate evidence | prove lawful processing | Needs legal/product retention decision |
| Voice/audio | pronunciation or conversation feedback | No storage by default; needs explicit P0-05 approval |
| Operational telemetry | reliability and security | Minimize identifiers; duration needs SLO/support decision |

Export and deletion workflows must be asynchronous, auditable, retryable, and
able to report data that cannot be deleted for a documented legal reason.

## Initial threat model

| Threat | Required control |
| --- | --- |
| Token theft or local token used in production | External OIDC in production; issuer/audience validation; secure mobile storage |
| Cross-learner object access | Derive learner from token; object-level authorization tests |
| Duplicate or lost offline attempt | Durable outbox, stable mutation IDs, server deduplication, replay tests |
| Answer leakage | Separate authoring and learner-delivery models; contract tests |
| Malicious or invalid content publish | Roles, validation, review gate, audit, rollback |
| PII/token leakage through telemetry | Redaction, allowlisted fields, retention controls |
| Voice processed without consent | Explicit consent, purpose limitation, deletion, provider contract |
| Dependency compromise | Alert triage, pinned lockfiles/wrappers, focused upgrades, CI regression |

## Environments and promotion

| Environment | Identity | Data | Promotion |
| --- | --- | --- | --- |
| Local | Ephemeral local issuer only | Seed PostgreSQL | Developer validation |
| Test/CI | Test issuer and disposable database | Synthetic data only | All automated gates pass |
| Staging | External non-production OIDC | Production-like synthetic data | Release candidate and E2E approval |
| Production | External production OIDC | Controlled production data | Approved artifact promoted from staging |

Artifacts are built once per release candidate and promoted; production is not
rebuilt from an unreviewed source state. Migrations require forward-fix and
backup/restore procedures before the backend release gate.
