# Android advanced learning P1 evidence — 2026-07-31

## Result

Passed locally on 2026-07-31 in the Asia/Saigon timezone.

Journey:

`home → advanced media download → writing feedback → A1 placement → premium purchase/refund → support → catalog → course → lesson → feedback → progress`

The test used the real Flutter Android application, native Kotlin platform
channel, Spring Boot backend, Flyway V1–V6, and PostgreSQL. It did not use the P1
fake gateway or fake platform adapter.

## Environment

- Flutter 3.44.3
- Android emulator `emulator-5554`
- Android 17 / API 37, x86_64
- JDK 21.0.11
- Spring Boot 4.1.0
- PostgreSQL 18.4 from `postgres:18-alpine`
- Disposable database container without a persistent volume
- ADB reverse tunnel from emulator port 8080 to the local backend

## Command

From `apps/mobile`:

`flutter test integration_test/learning_flow_integration_test.dart --flavor local --dart-define=ESQUILO_ENV=local --dart-define=ESQUILO_API_URL=http://127.0.0.1:8080 -d emulator-5554`

Observed result:

`00:17 +1: All tests passed!`

The same run built and installed
`build/app/outputs/flutter-apk/app-local-debug.apk`.

## Supporting gates

- Dart format check passed for 75 files.
- Flutter analyzer reported no issues.
- All 37 Flutter tests passed.
- All 30 backend tests passed with zero failures.
- Backend `bootJar` passed.
- Accessibility review found no provable static issue; widget tests exercised
  200% text scaling, labeled controls, live regions, and Android tap targets.

## Cleanup

- The backend process was stopped.
- The disposable `esquilospeak_p1_db` container was stopped and removed.
- The ADB reverse tunnel was removed.
- `emulator-5554` was stopped.

## Remaining release verification

Android emulators cannot validate real microphone capture. Pronunciation
recording still requires physical-device regression, and production media,
speech/AI providers, Google Play Billing, signing, store policy, and staged
rollout remain Phase 13 gates.
