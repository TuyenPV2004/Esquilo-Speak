# EsquiloSpeak mobile

Flutter Android learner application. Phase 11 builds the core learner journey
on the Phase 10 foundation: onboarding and profile, language/course/lesson
selection, attempts and feedback, progress/mastery/review, offline cache/outbox,
daily goal, privacy controls, and accessible responsive navigation.

Phase 12 completes the closed-testing Android P1 experience: authenticated media
playback and private offline download, pronunciation recording with runtime
permission and raw-voice deletion disclosure, writing/conversation feedback,
course-specific placement with a versioned proficiency reference and a non-accredited completion record, explainable offline-first
recommendations and mastery insight, streak/achievement/reminder, premium
entitlement purchase/refund simulation, and support/content reports.

Closed testing deliberately uses deterministic backend providers and a local
purchase verifier. Production media/STT/AI providers and Google Play Billing are
release integrations, not silent fallbacks.

Home V2 composes one daily session from due reviews, the weakest concept, or the
next incomplete lesson. It exposes one primary CTA, caps the visible review
backlog using the server policy, reuses downloaded lesson content for 3–5 minute
quick practice, and keeps daily goal progress separate from streak. Rewarded
engagement events require canonical evidence; daily-session lifecycle events are
measurement-only and never award XP or streak credit.

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

Unit 1 có thêm Android instrumentation độc lập, đi qua learning path, tải unit và
toàn bộ 5 lesson/45 exercise bằng repository xác định:

```powershell
flutter test integration_test/unit_one_android_integration_test.dart `
  --flavor local -d emulator-5554
```

Learning path lưu manifest download theo course/unit và exact lesson version. Chỉ khi
toàn bộ payload đã cache thì unit mới hiện trạng thái tải xong; tải lại cùng version là
idempotent và nội dung vẫn đọc được khi offline.

If host networking blocks `10.0.2.2`, use a temporary ADB reverse tunnel:

```powershell
adb reverse tcp:8080 tcp:8080
flutter test integration_test/learning_flow_integration_test.dart `
  --flavor local `
  --dart-define=ESQUILO_ENV=local `
  --dart-define=ESQUILO_API_URL=http://127.0.0.1:8080 `
  -d emulator-5554
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
  offline attempts, deterministic learning recommendations, learning insights,
  and sync reconciliation.
- Widget tests cover learner behavior, accessibility guidelines, large text,
  personalized insight copy/actions, P1 forms and permission denial, and
  Vietnamese/English localization key parity.
- Integration tests cover authenticated media download, writing feedback,
  course-specific placement, premium purchase/refund, support, and the original learner journey
  against the real backend and PostgreSQL.
- Golden tests are added only for stable shared components or screens with
  deterministic fonts and dimensions; every image diff requires review.
