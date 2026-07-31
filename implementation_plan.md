# Kế hoạch loại bỏ hardcode cản trở mở rộng

## 1. Mục tiêu

Loại bỏ các giả định cố định đang khiến runtime hoạt động như ứng dụng Việt–Anh A1, đồng thời chuẩn hóa contract và policy để có thể bổ sung course, target language, proficiency framework, exercise type, advanced activity và engagement rule mà không sửa logic rải rác.

Kế hoạch bám theo Giai đoạn 1–3 và các dependency engagement/commerce trong `docs/plans/Ke_Hoach_2.md`. Backend và contract được hoàn thiện, kiểm tra trước Android consumer tương ứng. Giai đoạn 13 vẫn bị khóa.

## 2. Phạm vi được đề nghị phê duyệt

### Bước 1 — Learning context và active course

- Backend: mở rộng learner profile bằng active course có kiểm tra course/source/target language hợp lệ; thêm migration mới thay vì sửa migration V1–V7.
- Contract: cập nhật profile request/response và tài liệu API theo hướng backward-compatible.
- Android: onboarding chọn source/target language từ catalog, lưu active course, và để learning/placement/advanced feature đọc cùng một `LearningContext`; bỏ fallback `vi`, `en` trong production path.
- File dự kiến: module `identityprofile` và `curriculumcontent`, OpenAPI; `learner_profile_*`, `onboarding_screen.dart`, `learning_view_model.dart`, dependency/router liên quan và test tương ứng.

### Bước 2 — Exercise contract và engine V2 nền tảng

- Mở rộng JSON Schema/OpenAPI bằng discriminated `response` và scoring result, giữ adapter tương thích cho `selectedOptionId` trong thời gian chuyển tiếp.
- Backend tách validator/scorer theo exercise type; không mặc định mọi type ngoài true/false là multiple choice.
- Android tách renderer/response theo exercise type và giữ P0 multiple-choice/true-false hoạt động.
- File dự kiến: `contracts/schema/common.schema.json`, `lesson.schema.json`, `lesson-delivery.schema.json`, OpenAPI; `CurriculumContentAdminService.java`, `CurriculumContentService.java`, `LearningController.java`, `LearningService.java`; learning models/repository/view-model/screen cùng contract, unit, widget và integration tests.

### Bước 3 — Advanced activity context và locale đúng vai trò

- Đưa `activityId`, course/lesson/content reference, media, expected input, target locale và feedback locale vào activity definition do content/lesson cung cấp.
- Bỏ `a1-hello`, câu pronunciation và `lesson-basic-greetings` khỏi production UI/view-model; support nhận content reference từ navigation context.
- File dự kiến: contract lesson/advanced-learning, module `advancedlearning`/`support`; `advanced_practice_screen.dart`, `p1_view_model.dart`, `support_screen.dart`, model/API và tests liên quan.

### Bước 4 — Engagement server-authoritative và timezone-aware

- Client gửi evidence/activity attempt; server quyết định event hợp lệ và XP theo versioned policy.
- Lưu IANA timezone trong preference và tính learning date/streak theo timezone đó.
- Achievement được trả từ catalog/presentation metadata; client có fallback an toàn cho code chưa biết.
- Reminder dùng preference người học thay cho 19:30 cố định.
- File dự kiến: migration mới; module `engagement`, listener/evidence từ `learning`/`advancedlearning`, OpenAPI; `p1_api_service.dart`, `p1_view_model.dart`, engagement/reminder UI/native bridge, localization và tests.

### Bước 5 — Catalog, localization và policy còn lại

- Tạo API/admin boundary cho proficiency framework/level và placement definition/version; không yêu cầu migration cho mỗi assessment mới.
- Tách feedback code khỏi map chỉ có VI/EN; true/false label lấy từ localized content/resource.
- Version hóa strategy/parameter cho mastery và review scheduler.
- Đưa product/entitlement mapping cùng privacy/retention/service-policy values vào typed configuration hoặc versioned policy phù hợp; giữ local closed-testing adapter tách biệt.
- Đánh giá `proficiency_framework_languages` many-to-many và media/skill controlled vocabulary; chỉ migration khi đã có test chuyển đổi và compatibility rõ ràng.

## 3. Tài liệu phải đồng bộ

- `contracts/openapi/esquilospeak-learning-v1.yaml` là nguồn chuẩn API.
- `docs/reference/API_Check.md` và `docs/shared/Guide.md` được cập nhật cùng mọi thay đổi API hoặc ma trận test tay.
- `docs/plans/Ke_Hoach_2.md` chỉ đánh dấu `[x]` khi artifact và quality gate tương ứng đã pass.
- `docs/process/Development_Change_Log.md` ghi đầy đủ từng nhóm thay đổi.

## 4. Chiến lược tương thích và migration

- Không sửa các migration V1–V7 đã tồn tại; tạo migration kế tiếp có forward migration rõ ràng.
- Duy trì đọc payload P0 hiện tại trong một vòng chuyển tiếp; không xóa `selectedOptionId` cho đến khi mobile, offline outbox và fixture đã chuyển hết sang `response`.
- Seed Việt–Anh A1 tiếp tục là dữ liệu demo/closed testing, không được dùng làm production fallback.
- Không mở rộng native iOS; chỉ giữ shared Flutter code không bị phụ thuộc Android ngoài platform boundary hiện có.

## 5. Validation bắt buộc

1. Contract: parse JSON Schema, Redocly lint, release-freeze/backward-compatibility review.
2. Backend: `compileJava`, `compileTestJava`, integration/security tests, Spring Modulith verification, full test và `bootJar`; migration chạy trên PostgreSQL/Testcontainers.
3. Android: Dart format, `flutter analyze`, toàn bộ `flutter test`, widget/integration regression và Android local debug APK.
4. E2E: onboarding chọn language/course → lesson/attempt/offline sync → advanced activity → engagement/reminder với backend/PostgreSQL thật.
5. Static audit: không còn production fallback `vi → en`, A1/content ID, XP, reminder time hoặc entitlement mapping tại các vị trí đã nêu; local/test fixture được loại trừ rõ ràng.

## 6. Rủi ro và cách kiểm soát

- Thay đổi attempt contract có thể ảnh hưởng offline outbox: dùng adapter chuyển tiếp và fixture regression.
- Active course/profile migration có thể làm hồ sơ cũ thiếu dữ liệu: cho phép `null` trong giai đoạn chuyển tiếp và yêu cầu chọn course khi vào learning.
- Timezone thay đổi cách tính streak: lưu occurrence instant và policy version, kiểm thử tại biên ngày/DST.
- Scope lớn dễ tạo refactor dàn trải: triển khai theo năm bước độc lập, mỗi bước chỉ tiếp tục sau khi quality gate bước trước pass.

## 7. Trạng thái phê duyệt

- Rule hạn chế hardcode: đã được developer yêu cầu bổ sung.
- Thay đổi application/contract/schema/migration: developer đã phê duyệt; triển khai và quality gate đang được thực hiện.
- Slice i18n/l10n và presentation metadata: đã hoàn tất ngày 2026-07-31 với
  Flyway V12, OpenAPI lint, backend test, Flutter analyzer/test và Android debug
  APK. Các policy sản phẩm còn lại như goal catalog, daily-session composer và
  recommendation strategy tiếp tục thuộc Giai đoạn 5 của `Ke_Hoach_2.md`, không
  được giả lập thành cấu hình locale.
