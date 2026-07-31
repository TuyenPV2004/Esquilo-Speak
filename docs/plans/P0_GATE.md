# P0 decision and delivery gate

- Status: Accepted
- Started: 2026-07-30
- Accepted: 2026-07-30
- Target client: Android
- Public distribution: Not authorized by this decision

This file is the version-controlled execution gate for Sprint B / Phase 4.
Country-specific public release remains gated even though the P0 development
scope is accepted.

## Accepted product decisions

| ID | Decision | Accepted position |
| --- | --- | --- |
| P0-01 | First market and launch countries | Market-neutral product configuration. P0 is limited to internal/closed testing until distribution countries pass a separate legal, privacy, tax, store, and support release review. |
| P0-02 | First source and target language pair | Default `vi` source and `en` target. Vietnamese is the default UI locale. Language pairs remain configuration-driven; no English regional variant is selected in P0. |
| P0-03 | Minimum age and whether minors are in scope | No minimum learning age. Use a neutral age band (`under_16`, `16_17`, `adult`) only when an account or synchronized processing requires it. Under-16 learners remain in restricted guest mode unless a compliant guardian-consent flow is available. |
| P0-04 | Guest lifetime, account creation, and guest-account merge | Pseudonymous guest, no required contact data, 90-day inactivity retention, explicit and idempotent one-guest-to-one-account merge. Failed merge leaves guest data intact. |
| P0-05 | Consent model and voice/audio retention | Versioned purpose-specific consent. P0 does not collect or upload voice. A later speech feature requires just-in-time microphone permission and a separate accepted retention design. |
| P0-06 | Account export/deletion response targets and retention exceptions | Acknowledge within 24 hours; export JSON/CSV within 7 days; revoke sessions immediately on verified deletion; delete active data within 30 days; backups expire within 90 days; keep only documented, minimized legal/security records. |
| P0-07 | P0 subscription scope | Excluded from P0. Core learning remains free for P0. Add only an entitlement boundary when a concrete P1 commerce use case is accepted. |
| P0-08 | Initial learning outcome, product success metrics, and SLO | Learning-evidence weekly active learner is the north-star metric. Initial quality and reliability targets are defined below and reviewed after 30 days of closed-test data. |
| P0-09 | Support channels and response policy | Email or web form; Vietnamese primary and English secondary. Privacy/security/access requests target 24-hour acknowledgement, functional issues 3 business days, content issues 5 business days. No 24/7 commitment in P0. |

These decisions are governed by
[`ADR-004`](../decisions/ADR-004-p0-product-privacy-and-service-decisions.md).
They authorize Sprint C contract and backend work, but do not authorize a
public country launch.

## Identity, age, and guest invariants

- The platform stores an opaque external subject mapping; it does not own
  production credentials.
- A guest identifier is pseudonymous and does not require name, email, phone,
  full date of birth, or exact age.
- Age band is collected only at the point where account or synchronized
  processing requires it.
- Under-16 learners have no personalized advertising, non-essential tracking,
  server voice upload, AI training use, or account sync without an accepted
  guardian-consent flow.
- Guest-to-account merge is explicit, transactional, auditable, and
  idempotent. Attempts are append-only and deduplicated by their stable IDs;
  account profile, locale, and consent win on profile-field conflicts.
- A guest token is revoked only after merge succeeds. A failed merge can be
  retried without losing or duplicating progress.
- One guest can merge into at most one account.

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
| Subscription and entitlement | P1 | Explicitly excluded from P0 |
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

## Privacy inventory and retention

| Data class | Purpose | P0 retention |
| --- | --- | --- |
| Identity subject mapping | Authenticate and merge accounts | Until verified deletion completes; retain only a minimized, pseudonymized security record when documented |
| Learner profile/preferences | Personalize learning | Until account deletion |
| Guest profile, attempts, and progress | Trial learning and continuity | Until merge, explicit deletion, or 90 days of guest inactivity |
| Account attempt and progress history | Learning continuity and outcome | Until account deletion |
| Consent and age-band evidence | Enforce and demonstrate processing choices | Current record while active; minimized audit record for 180 days after withdrawal or deletion |
| Voice/audio | Pronunciation or conversation feedback | Not collected in P0 |
| Operational telemetry | Reliability and security | Allowlisted, pseudonymous fields for 30 days; security events up to 180 days |
| Export artifacts | Fulfil a verified data request | Delete within 7 days after download availability expires |
| Database backups | Disaster recovery | Rolling expiry within 90 days; deleted data is not restored into active use |

Export and deletion workflows are asynchronous, auditable, retryable, and able
to report data that cannot be deleted for a documented legal reason. The app
must expose an in-app deletion path and a public web request path before account
creation is enabled in a public build.

## Consent purposes

Consent is versioned and recorded per purpose. Withdrawing one optional purpose
must not withdraw unrelated purposes or delete learning progress.

| Purpose | P0 behavior |
| --- | --- |
| Required service processing | Explained at guest/account activation; limited to delivering and synchronizing learning |
| Operational telemetry | Minimal and pseudonymous; non-essential analytics remains off until explicitly enabled |
| Marketing and personalized notifications | Off by default; separate opt-in |
| Microphone and server speech processing | Not available in P0 |
| Voice retention and model training | Not available in P0; future use requires separate explicit opt-in |

## Initial success metrics and service levels

- North star: weekly learners who complete at least one learning session with
  mastery or completion evidence.
- At least 60% of learners who start the first lesson complete it.
- Zero confirmed loss of an acknowledged attempt.
- Fewer than 0.01% of accepted attempts are duplicate logical mutations.
- Monthly backend API availability target: 99.5%.
- Ordinary API latency targets: read p95 at or below 500 ms and mutation p95 at
  or below 800 ms, excluding future AI and media processing.
- Android crash-free session target: at least 99.5%.
- Backup recovery objectives: RPO 24 hours and RTO 4 hours.
- These are internal P0 targets, not public contractual commitments. Rebaseline
  them after 30 days of representative closed-test data.

## P0 acceptance criteria

Sprint C and later P0 work must preserve these observable outcomes:

1. A new learner can begin as a pseudonymous guest without contact information.
2. The default course discovery request resolves the `vi` to `en` pair without
   hard-coding that pair into domain logic.
3. Account or sync activation applies the accepted age-band restrictions and
   records the policy/consent version.
4. Repeating the same guest merge returns the canonical result and creates no
   duplicate learner, attempt, or progress records.
5. A failed merge leaves the guest usable and can be retried safely.
6. Export and deletion requests expose an auditable state and meet the response
   targets above in automated clock-controllable tests.
7. Production configuration rejects the local issuer and uses an external
   issuer with issuer and audience validation.
8. Logs, traces, exports, and error responses contain no token, raw voice, or
   unnecessary personal data.
9. Subscription, paywall, voice upload, and AI training are absent from the P0
   learner journey.

## Dependency-ordered delivery backlog

1. Sprint C: identity/profile contract, external subject mapping, pseudonymous
   guest lifecycle, age band, versioned consent, merge, export/delete request,
   and authorization/security tests.
2. Sprint D: versioned curriculum/content lifecycle, authoring separation,
   publish/retire/rollback, and learner-delivery compatibility.
3. Sprint E: durable mobile outbox contract, mastery evidence, review scheduler,
   sync cursor/conflict behavior, and replay/concurrency tests.
4. Sprint F: telemetry retention enforcement, SLO measurement, backup/restore,
   audit, security review, and release runbooks.
5. Sprint G: Android onboarding, guest/account UX, privacy controls, durable
   offline storage, and end-to-end integration after each backend gate.

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
