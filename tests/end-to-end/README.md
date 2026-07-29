# Android end-to-end learning journey

The executable test lives at:

`apps/mobile/integration_test/learning_flow_integration_test.dart`

It runs the Flutter application on an Android emulator against the real Spring
backend and PostgreSQL. GitHub Actions starts all three components in the
`android-end-to-end` job.

For a local run:

1. Start PostgreSQL and the backend with the `local` profile.
2. Start an Android emulator that can reach the host backend.
3. From `apps/mobile`, run:

   `flutter test integration_test/learning_flow_integration_test.dart -d <device-id>`

The Android debug manifest permits cleartext traffic only for development.
Production traffic must use HTTPS.
