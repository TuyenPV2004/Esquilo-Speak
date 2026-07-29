# Android learning journey evidence — 2026-07-30

## Result

Passed locally on 2026-07-30 in the Asia/Saigon timezone.

Journey:

`catalog → course → lesson → answer → feedback → progress`

The test used the real Flutter Android application, Spring Boot backend, Flyway
migration, and PostgreSQL. It did not use `FakeLearningRepository`.

## Environment

- Flutter 3.44.3
- Dart 3.12.2
- Android emulator `emulator-5554`
- Android 17 / API 37, x86_64
- JDK 21.0.11
- Spring Boot 4.1.0
- PostgreSQL 18.4 from the `postgres:18-alpine` image
- Disposable database container without a persistent volume
- Spring config import overridden so the run did not read the repository
  `.env`

## Command

From `apps/mobile`:

`flutter test integration_test/learning_flow_integration_test.dart -d emulator-5554 --dart-define=ESQUILO_API_URL=http://10.0.2.2:8080`

Observed result:

`00:41 +1: All tests passed!`

## Cleanup

- The backend process was stopped.
- The disposable `esquilo_e2e_validation` container was stopped and removed.
- `emulator-5554` was stopped.

## Remaining external verification

The GitHub Actions `android-end-to-end` job uses an API 35 Pixel 7 Pro emulator.
That runner configuration must pass on the first pull request before Sprint A
is considered closed in the shared repository.
