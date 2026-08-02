# ADR-006 — Android application foundation P0

- Status: Accepted
- Date: 2026-07-30
- Scope: Phase 10 / Android application foundation

Amendment (2026-08-02): ADR-010 approves the first-party product-quality sink
after defining its consent, allowlist, retention and verification controls. It
supersedes only the no-op product-analytics part of Decision 11. Third-party
analytics and crash-report providers remain disabled and separately gated.

## Context

The existing Flutter vertical slice called the backend directly and stored no
durable session, pending mutation, or sync cursor. It also had no environment
separation, centralized navigation, secure token lifecycle, or consent-aware
telemetry boundary. Phase 10 must establish these boundaries before the learner
journey expands in Phase 11.

The backend P0 contract already defines idempotent attempts, an offline outbox
push, canonical cursor-based pull, OAuth/OIDC bearer authentication, problem
responses, and correlation IDs. The mobile foundation must follow that contract
without introducing infrastructure or state-management complexity that the
current application does not need.

## Decision

1. Keep the feature-first presentation/repository structure and compose
   dependencies explicitly in `AppDependencies`. Do not add a state-management
   framework until screen coordination demonstrates a concrete need.
2. Use `go_router` for declarative navigation and a single route table. It
   provides deep-link-ready routing without a custom Router implementation.
3. Use `sqflite` for the local outbox, canonical change cache, sync cursor, and
   non-sensitive preferences. Use `sqflite_common_ffi` only for deterministic
   database tests. Drift was considered but rejected for P0 because its
   code-generation and abstraction cost is not yet justified by the small
   schema.
4. Use `flutter_secure_storage` only for authentication tokens. Never place
   bearer, refresh, or identity tokens in SQLite or normal preferences.
5. Use `flutter_appauth` for provider-neutral OAuth 2.0/OIDC Authorization Code
   with PKCE, refresh, and end-session flows. External issuer and client
   configuration remain environment-provided; no identity vendor is embedded.
6. Retain the existing `http` package and wrap it in `ApiClient`. Dio was
   considered but rejected because timeout, correlation, one-refresh-on-401,
   problem mapping, and bounded retry behavior are small enough to implement
   and test without another foundational dependency.
7. Retry safe reads and mutations carrying an idempotency key only. Preserve one
   correlation ID and logical mutation identifiers across automatic retries.
   Do not retry arbitrary non-idempotent writes.
8. Persist a mutation before attempting delivery. Push the durable outbox, then
   pull canonical changes and advance the opaque cursor transactionally. Do not
   infer server truth from connectivity status, so no connectivity plugin is
   added.
9. Define `local`, `staging`, and `production` Android flavors. Permit cleartext
   traffic only in the local flavor; require HTTPS for staging and production.
   Runtime endpoints and OIDC identifiers come from `--dart-define`, not source
   or packaged secret files.
10. Use a Material 3 light/dark theme with centralized tokens, common loading,
    empty, error, and offline states, a 48 dp minimum interactive target,
    bounded responsive content, and reduced-motion support.
11. Put analytics and crash reporting behind `ConsentAwareTelemetry`. Collect
    nothing before opt-in, allow-list non-sensitive attributes, and use a no-op
    sink until a production provider and privacy review are approved.
12. Validate the foundation with unit tests, accessibility widget tests,
    localization key parity, the existing journey tests, and an Android flavor
    build. Add golden files only for stable shared components or screens with
    deterministic fonts, dimensions, and reviewed image diffs.

## Consequences

- Phase 11 can add screens and repositories without changing the session,
  transport, storage, navigation, or environment boundaries.
- Authentication secrets are encrypted by platform-backed secure storage, while
  offline learning data remains queryable and recoverable in SQLite.
- The local guest gateway remains a development adapter. Staging and production
  are intentionally unavailable until complete external OIDC settings exist.
- A production telemetry/crash provider, real staging OIDC validation, release
  signing, and device-matrix end-to-end testing remain release gates rather than
  hidden defaults.
- If the local schema or reactive query needs become substantially more
  complex, the team should revisit Drift. If transport policy grows beyond this
  wrapper, the team should revisit Dio or generated OpenAPI clients.

## Verification

- `dart format --output=none --set-exit-if-changed lib test integration_test`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug --flavor local
  --dart-define=ESQUILO_ENV=local`

## References

- [Flutter app architecture](https://docs.flutter.dev/app-architecture/guide)
- [Flutter offline-first architecture](https://docs.flutter.dev/app-architecture/design-patterns/offline-first)
- [Flutter navigation](https://docs.flutter.dev/ui/navigation)
- [Flutter Android flavors](https://docs.flutter.dev/deployment/flavors)
- [Flutter accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing)
- [RFC 8252 — OAuth 2.0 for native apps](https://www.rfc-editor.org/rfc/rfc8252.html)
- [RFC 9700 — OAuth 2.0 security best current practice](https://www.rfc-editor.org/rfc/rfc9700.html)
- [Android network security configuration](https://developer.android.com/privacy-and-security/security-config)
- [OWASP MASVS](https://mas.owasp.org/MASVS/)
