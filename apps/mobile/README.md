# EsquiloSpeak mobile

Flutter Android learner application. Phase 11 builds the core learner journey
on the Phase 10 foundation: onboarding and profile, language/course/lesson
selection, attempts and feedback, progress/mastery/review, offline cache/outbox,
daily goal, privacy controls, and accessible responsive navigation.

## Local development

The Android emulator resolves the local backend through
`http://10.0.2.2:8080`. Start the local flavor with:

```powershell
flutter pub get
flutter run --flavor local --dart-define=ESQUILO_ENV=local
```

Override the local API when needed:

```powershell
flutter run --flavor local `
  --dart-define=ESQUILO_ENV=local `
  --dart-define=ESQUILO_API_URL=http://10.0.2.2:8080
```

Only the local flavor allows cleartext HTTP. Staging and production require an
HTTPS API URL and a complete external OIDC configuration:

```powershell
flutter run --flavor staging `
  --dart-define=ESQUILO_ENV=staging `
  --dart-define=ESQUILO_API_URL=https://api.staging.example `
  --dart-define=ESQUILO_OIDC_ISSUER=https://identity.staging.example `
  --dart-define=ESQUILO_OIDC_CLIENT_ID=esquilospeak-mobile-staging `
  --dart-define=ESQUILO_OIDC_REDIRECT_URL=com.esquilospeak.mobile.staging://oauthredirect `
  --dart-define=ESQUILO_OIDC_POST_LOGOUT_REDIRECT_URL=com.esquilospeak.mobile.staging://oauthredirect
```

The values above are placeholders, not credentials. Do not commit tenant
secrets, tokens, or environment files.

## Validation

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build apk --debug --flavor local --dart-define=ESQUILO_ENV=local
```

CI also runs the learner journey against PostgreSQL, the backend, and an Android
emulator:

```powershell
flutter test integration_test/learning_flow_integration_test.dart `
  --flavor local --dart-define=ESQUILO_ENV=local -d emulator-5554
```

## Storage, security, and telemetry

- Bearer, refresh, and identity tokens are stored only through platform secure
  storage.
- SQLite stores cached catalog/course/lesson/profile/insight payloads, pending
  mutations, canonical sync changes, the opaque cursor, and non-sensitive
  settings. Schema V2 migrates existing Phase 10 databases in place.
- A write is persisted before delivery; only safe reads and idempotent mutations
  are retried automatically.
- Offline content remains readable, attempt mutations stay pending until sync,
  and the UI exposes cached, pending, retry, conflict, and authentication states.
- Analytics and crash events are disabled until consent is stored. The P0 sink
  is deliberately no-op until a provider and privacy review are approved.

## Test strategy

- Unit tests cover environment validation, session rotation/logout, network
  retry/error policy, SQLite migration/cache/outbox, profile/privacy contracts,
  offline attempts, learning insights, and sync reconciliation.
- Widget tests cover learner behavior, accessibility guidelines, large text,
  and Vietnamese/English localization key parity.
- Integration tests cover the local Android journey against the real backend.
- Golden tests are added only for stable shared components or screens with
  deterministic fonts and dimensions; every image diff requires review.
