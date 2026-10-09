# Giai đoạn 9 — Unit 1 Android emulator evidence

- Date: 2026-08-02 (`Asia/Saigon`)
- Candidate scope: local debug, Stage 9 technical regression
- Device: Android emulator, API 37, x86_64 (`emulator-5554`)
- Test: `integration_test/unit_one_android_integration_test.dart`
- Result: PASS, 1/1 test

## Command

```powershell
flutter test integration_test/unit_one_android_integration_test.dart `
  --flavor local -d emulator-5554
```

## Evidence

- Gradle assembled and installed `app-local-debug.apk` successfully.
- The deterministic Android journey downloaded Unit 1 and completed all 5 lessons/
  45 exercises.
- Flutter reported `All tests passed!`; wall-clock duration was 183 seconds.

## Boundary

This is technical emulator evidence for one API level. It is not a closed-beta
cohort bundle and does not satisfy the required three API-level buckets, two
physical device models, physical microphone passes, live-backend offline/reconnect
journey, D1/D7 metrics, qualitative feedback or product sign-off.
