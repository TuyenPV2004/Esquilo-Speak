# Android end-to-end learning journey

The executable test lives at:

`apps/mobile/integration_test/learning_flow_integration_test.dart`

It runs the Flutter application on an Android emulator against the real Spring
backend and PostgreSQL. The journey covers advanced P1 media download, writing,
placement, closed-testing premium purchase/refund, support, and the original P0
learning flow. GitHub Actions starts all three components in the
`android-end-to-end` job.

For a local run:

1. Start PostgreSQL and the backend with the `local` profile.
2. Start an Android emulator that can reach the host backend.
3. From `apps/mobile`, run:

   `flutter test integration_test/learning_flow_integration_test.dart -d <device-id>`

The Android debug manifest permits cleartext traffic only for development.
Production traffic must use HTTPS.

When emulator-to-host routing through `10.0.2.2` is blocked, use
`adb reverse tcp:8080 tcp:8080` and set
`ESQUILO_API_URL=http://127.0.0.1:8080` for that local run.
