# Unit 1 Android instrumentation — 2026-08-01

## Phạm vi

- Thiết bị: Android emulator `emulator-5554`, API 37.
- Variant: `localDebug`.
- Test: `apps/mobile/integration_test/unit_one_android_integration_test.dart`.
- Hành trình: learning path, tải Unit 1, 5 lesson và 45 exercise thuộc 9 type.

## Kết quả

Gradle `app:connectedLocalDebugAndroidTest` hoàn tất với `BUILD SUCCESSFUL` trong
5 phút 27 giây; 195 task, 60 executed và 135 up-to-date. APK ứng dụng và APK test
được build, cài và chạy bằng Android instrumentation trên emulator.

Test dùng repository xác định để cô lập UI/runtime Android. Backend thật được kiểm
chứng riêng bằng integration test xử lý 45/45 attempt, 5/5 lesson, progress, mastery
evidence và review schedule. Vì hai bằng chứng chưa phải một hành trình liên thông,
gate learner mới đi từ onboarding tới hoàn thành Unit 1 vẫn để mở.

Trong quá trình chuẩn bị instrumentation, package test-only
`com.esquilospeak.mobile.local` trên emulator được gỡ để xử lý debug-signature mismatch;
dữ liệu cục bộ của package test đó không thể khôi phục.
