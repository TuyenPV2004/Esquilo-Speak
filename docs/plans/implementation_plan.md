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

## 8. Sửa lỗi Placement Test dùng sai locale

### Mục tiêu

Giữ chrome của màn hình Xếp trình độ theo `uiLocale`, nhưng bắt buộc prompt và
đáp án của assessment dùng locale nội dung thuộc course target để score phản ánh
khả năng target language thay vì khả năng đọc bản dịch.

### Nguyên nhân đã xác nhận

`PlacementScreen` truyền `Localizations.localeOf(context)` vào resolver của cả
`question.prompt` và `option.text`. Assessment đã trả `defaultLocale: en`, nhưng
field này chỉ được dùng làm fallback nên bản `vi` được ưu tiên khi UI là tiếng Việt.

### File dự kiến thay đổi

- `apps/mobile/lib/features/assessment/presentation/placement_screen.dart`.
- `apps/mobile/test/learner_journey/p1_screens_test.dart`.
- `apps/mobile/test/support/p1_fakes.dart` để fixture có cùng prompt/option EN/VI
  đã gây lỗi trong dữ liệu local.
- `docs/process/Walkthrough.md` và
  `docs/process/errors/Error_Placement_Target_Language.md`.
- `docs/process/Development_Change_Log.md` sau khi validation hoàn tất.

### Cách triển khai

1. Tách `uiLocale` dùng cho format/chrome khỏi `assessmentLocale` dùng cho nội dung test.
2. Resolve prompt và option theo `assessment.defaultLocale`.
3. Thêm widget regression test với UI `vi`, assessment `en`; kiểm tra prompt và
   các option English xuất hiện, bản dịch Vietnamese không xuất hiện.
4. Không sửa API/schema/migration vì assessment response đã có locale canonical.

### Validation

1. `dart format --output=none --set-exit-if-changed` cho source/test thay đổi.
2. `flutter analyze` và targeted/full Flutter test nếu SDK khả dụng.
3. P0 release-freeze validator và JSON Schema parse.
4. Kiểm tra local Markdown link, UTF-8 và `git diff --check`.

### Rủi ro và kiểm soát

- `defaultLocale` phải tiếp tục là locale canonical của assessment content; test
  fixture và backend integration hiện bảo vệ giá trị `en` cho course target English.
- Chỉ thay presentation resolution; answer ID, submission order và scoring không đổi.

### Phê duyệt

Developer đã phê duyệt thực hiện bản sửa ngày 2026-08-01 bằng yêu cầu “Thực hiện sửa”.

### Kết quả

- Implementation hoàn tất: prompt và option dùng `assessment.defaultLocale`;
  chrome tiếp tục dùng `uiLocale`.
- Targeted Placement/P1 widget suite: 6 test pass.
- Dart format pass và Flutter analyzer không có issue trong container Flutter
  3.44.0/Dart 3.12.0; repo vẫn giữ constraint Flutter 3.44.3/Dart 3.12.2.
- 42 test khác pass trong full-suite run; P0 fixture test pass khi chạy lại với
  layout thư mục tạm đúng repository.

## 9. Giai đoạn 2 — Content contract và authoring pipeline

### Mục tiêu

Cho phép content author tạo một content package có version, validate schema và
ngữ nghĩa, tạo learner-safe preview, nhập/cập nhật draft và điều khiển lifecycle
backend mà không sửa Dart hoặc Java cho từng lesson.

### Phạm vi triển khai

1. Mở rộng JSON Schema authoring bằng các phần tách biệt: learning item,
   presentation, answer policy và feedback rule; bổ sung outcome, prerequisite,
   difficulty, hint, media và accessibility metadata.
2. Tạo content package mẫu gồm course, unit, lesson, exercise snippet, media
   manifest và review evidence.
3. Tạo CLI Node.js không thêm dependency để validate cấu trúc/ngữ nghĩa, compile
   package sang admin API payload, sinh learner-safe preview, import/update draft,
   transition lifecycle và rollback.
4. Bổ sung review evidence bắt buộc khi chuyển draft sang review; lưu evidence
   trong content audit hiện có và bảo toàn lifecycle/versioning hiện hành.
5. Dùng một package demo làm contract fixture và backend integration evidence cho
   luồng tạo → review → approve → publish → version mới → rollback/retire.
6. Ghi rõ ngưỡng chỉ xây admin web/CMS khi content-as-code trở thành bottleneck
   vận hành đã đo được.

### Khu vực dự kiến thay đổi

- `contracts/schema/` và contract OpenAPI content transition.
- `content/templates/`, `content/examples/`, `content/tools/` và hướng dẫn content.
- Backend `curriculumcontent` cùng integration test; không thêm migration nếu audit
  evidence có thể lưu an toàn trong `content_audit_events.details` hiện có.
- `tests/content/` cho validator/compiler/preview/HTTP adapter.
- Roadmap, README/API guide, change log và tài liệu authoring/review.

### Validation

1. Parse toàn bộ JSON Schema và validate package demo/fixture lỗi bằng content CLI.
2. Chạy Node content pipeline tests và kiểm tra preview không chứa answer/explanation.
3. Chạy OpenAPI lint và P0 release-freeze validator.
4. Chạy backend compile, curriculum-content integration test, full test, Modulith
   verification và `bootJar` với PostgreSQL/Testcontainers.
5. Kiểm tra Markdown link, UTF-8 và `git diff --check`.

### Giả định và rủi ro

- Giai đoạn 3 mới triển khai renderer/scoring cho các exercise type mới; Giai đoạn
  2 chỉ khóa authoring contract và pipeline cho các type runtime đang hỗ trợ, đồng
  thời giữ extension boundary rõ ràng.
- CLI không lưu token; token content admin chỉ được đọc từ biến môi trường khi gọi
  backend và không được ghi vào artifact/log.
- Preview là adapter learner-safe tối thiểu dùng cùng compiled delivery shape; chưa
  thay thế visual QA trên thiết bị ở Giai đoạn 4.
- Yêu cầu “Thực hiện Giai đoạn 2” ngày 2026-08-01 được xem là phê duyệt mở công việc
  sau Giai đoạn 1. Curriculum owner sign-off riêng vẫn được ghi nhận trung thực nếu
  chưa có evidence.

### Kết quả

- Contract Draft 2020-12, package/template/example, validator structural/semantic,
  compiler, learner-safe preview và CLI HTTP lifecycle đã hoàn tất.
- Package demo compile đúng bằng backend integration fixture; Node pipeline test
  bảo vệ invalid content, answer leakage, HTTP adapter và review evidence.
- Backend bắt buộc bảy review check trước trạng thái review, lưu evidence vào audit
  hiện có và không cần migration mới.
- Integration test phát hành lesson từ compiled fixture, xác nhận learner payload
  không lộ answer/explanation và published version không thể bị ghi đè.
- OpenAPI nâng lên `0.8.0`; Redocly lint, P0 release-freeze, targeted/full backend
  test, Modulith verification và `bootJar` đã pass trên JDK 21/PostgreSQL 18.

## 10. Giai đoạn 3–4 — Exercise Engine V2 và Unit 1 vertical slice

### Mục tiêu

Mở rộng learner journey từ hai dạng chọn đáp án sang một engine dữ liệu hỗ trợ ít
nhất tám dạng bài P0, dùng cùng response/evidence contract, scoring canonical phía
server và offline outbox. Phát hành Unit 1 A1 gồm năm lesson theo đặc tả curriculum,
có resume, sửa lỗi trước tổng kết và cập nhật tiến độ.

### Phạm vi triển khai

1. Chuẩn hóa response theo `kind` và evidence theo schema độc lập UI; giữ adapter
   `selectedOptionId` trong một vòng tương thích.
2. Đăng ký validator/scorer cho multiple choice, true/false, flashcard,
   matching, listen-select, ordering, fill-blank, dictation và comprehension.
3. Mở rộng authoring/delivery schema và content pipeline; learner payload phải loại
   toàn bộ đáp án canonical nhưng giữ instruction, hint, media transcript và metadata
   accessibility cần cho silent mode.
4. Refactor Flutter renderer thành registry theo type; hỗ trợ option, text, thứ tự,
   ghép cặp và self-assessment, đồng thời ghi response time, hint, retry, confidence
   và input modality vào attempt/outbox.
5. Điều phối toàn bộ exercise trong lesson, lưu checkpoint resume, đưa câu sai qua
   mistake review trước summary và chỉ mở lesson kế tiếp khi lesson trước hoàn tất.
6. Author content-as-code Unit 1 gồm greetings, name, how-are-you, numbers-age và
   checkpoint-first-contact; mỗi lesson có 8–12 task và checkpoint trộn nhiều kỹ năng.
7. Bổ sung fixture/test contract, scorer, widget, offline serialization và E2E learner
   journey; chỉ đánh dấu roadmap theo evidence thật sự chạy được.

### Validation

1. Parse/validate toàn bộ JSON Schema; chạy content pipeline test, validate, compile
   và learner-safe preview cho Unit 1.
2. Redocly lint OpenAPI và P0 release-freeze/backward-compatibility validator.
3. Backend compile, targeted/full integration tests, Modulith verification và
   `bootJar` trên JDK 21/PostgreSQL Testcontainers.
4. Dart format, `flutter analyze`, full widget/unit test, integration test và Android
   debug APK khi Flutter SDK phù hợp khả dụng.
5. Static audit answer leakage, hardcode locale, stable ID/idempotency, Markdown,
   UTF-8 và `git diff --check`.

### Giả định và rủi ro

- Yêu cầu ngày 2026-08-01 là phê duyệt thay đổi contract/runtime cần thiết cho hai
  giai đoạn; không thêm framework hoặc dependency mới.
- Flashcard là self-assessment: cả `know` và `learning` đều là response hợp lệ để ghi
  evidence, không được diễn giải `learning` thành câu trả lời sai.
- Audio vẫn phải có transcript/silent path. Metadata/provenance được kiểm tra trong
  pipeline; chất lượng thu âm thật và curriculum-owner sign-off chỉ được đánh dấu khi
  có evidence tương ứng, không suy diễn từ test kỹ thuật.
- Writing/pronunciation/conversation P1 tiếp tục đi qua provider boundary hiện hữu;
  Unit 1 chỉ liên kết activity definition, không nhân đôi scorer bất định vào P0.

### Kết quả

- OpenAPI 0.9.0, ADR-009 và V13 đã khóa response/evidence contract; server chấm
  canonical chín type và learner delivery loại toàn bộ answer policy.
- Flutter renderer registry hỗ trợ option/boolean, flashcard, text, ordering và
  matching primitive; lesson runtime có hint/retry evidence, resume, mistake review,
  progress summary và lesson lock.
- Unit 1 V2 có 5 lesson, 45 exercise (9 task/lesson), 9 type, 3 activity P1 cùng
  transcript/provenance/silent metadata; content validator và learner-safe preview pass.
- Contract/content tests, release freeze, Redocly, backend full suite 35/35 cùng
  `bootJar`, Flutter analyzer và 46 test Flutter pass. Android device E2E chưa chạy vì không có
  thiết bị; APK retry bị Docker `unexpected EOF`, nên các gate tương ứng vẫn để mở.
- Media hiện mới là manifest/object-key/provenance, chưa có binary thu âm được content
  owner duyệt. Unit download chủ động và curriculum-owner sign-off cũng chưa có evidence.

## 11. Giai đoạn 4 — Đóng khoảng trống Unit 1 offline, media và Android E2E

### Mục tiêu

Đưa Unit 1 từ vertical slice có content/runtime sang một gói học có thể nhận diện theo
unit, tải trọn vẹn để học offline, dùng media nhị phân có thể kiểm chứng và có bằng
chứng E2E/QA mạnh nhất mà môi trường Android hiện tại cho phép.

### Phạm vi triển khai

1. Mở rộng lesson summary theo hướng tương thích ngược với `unitId`, `unitTitle` và
   `position`; learning path nhóm bài theo unit, hiển thị tiến độ cùng trạng thái
   khóa/mở bằng nhãn và icon, không chỉ bằng màu.
2. Thêm capability tải unit vào offline repository. Một download chỉ được đánh dấu
   hoàn tất sau khi summary và đúng version của mọi lesson trong unit đã được cache;
   tải lại cùng version phải idempotent và dữ liệu đã tải phải đọc được khi mất mạng.
3. Thay checksum/object placeholder của Unit 1 bằng tệp WAV thực được tạo từ TTS local,
   khai báo rõ engine/voice/provenance, transcript và silent alternative. Pipeline phải
   xác minh file tồn tại, checksum và duration thay vì chỉ kiểm tra hình thức metadata.
4. Bổ sung contract/backend/mobile/content test cho unit metadata, download và media;
   mở rộng integration journey để đi qua toàn bộ năm lesson/45 exercise khi fixture
   Android/backend phù hợp khả dụng.
5. Chạy content QA, accessibility/widget QA và Android E2E/APK. Checkbox Android hoặc
   content-owner sign-off chỉ đóng khi có bằng chứng thiết bị/người duyệt tương ứng.

### Validation

1. Content generator, validator, pipeline tests, compile và learner-safe preview Unit 1.
2. OpenAPI lint/release-freeze; backend targeted/full tests và `bootJar`.
3. Dart format, Flutter analyzer, targeted/full unit/widget tests, bao gồm offline
   download, trạng thái unit path và text scaling 200%.
4. `adb devices -l`, Flutter integration test và Android debug APK trên môi trường có
   thiết bị; ghi rõ blocker nếu không có target Android khả dụng.
5. `git diff --check`, rà soát answer leakage, checksum, provenance và roadmap evidence.

### Giả định và rủi ro

- Unit 1 là unit publish duy nhất của course version 2 hiện tại, nhưng contract/download
  được thiết kế theo `unitId` để không hardcode trường hợp một unit.
- TTS local tạo media nhị phân kỹ thuật và provenance trung thực; nó không thay thế
  language/content-owner review. Vì vậy sign-off chất lượng ngôn ngữ vẫn là gate riêng.
- Không thêm dependency phát audio trong lượt này nếu runtime hiện chưa có primitive
  phát media phù hợp; binary, delivery metadata và offline content phải sẵn sàng trước,
  còn playback thiết bị chỉ được đánh dấu khi đã chạy Android.
- Android E2E phụ thuộc thiết bị/emulator và backend local. Không suy diễn pass từ widget
  test hoặc build APK.

### Phê duyệt

Developer phê duyệt thực hiện ngày 2026-08-01 bằng yêu cầu ưu tiên Android E2E, unit
download và media thật để đóng các checkbox còn mở của Giai đoạn 4.

### Kết quả

- Contract 0.10.0 và backend trả `unitId`, `unitTitle`, `position`; Android nhóm learning
  path theo unit, hiển thị tiến độ/trạng thái bằng icon lẫn nhãn và có hành động tải unit.
- Offline repository chỉ hoàn tất manifest khi đúng version của toàn bộ lesson đã nằm
  trong cache; test xác nhận đọc mất mạng và tải lại idempotent. Outbox/sync regression
  tiếp tục xác nhận attempt không bị ghi trùng.
- Unit 1 có 10 tệp WAV TTS Microsoft Zira với transcript, silent alternative, SHA-256,
  duration và provenance. Validator đọc binary thật để đối chiếu checksum/duration;
  content-owner review vẫn là gate độc lập.
- Backend integration hoàn tất 45/45 attempt, 5/5 lesson, mastery evidence và review
  schedule. Flutter analyzer pass, 49/49 test pass, gồm text scaling 200%.
- `connectedLocalDebugAndroidTest` pass trên emulator Android API 37 cho learning path,
  unit download và toàn bộ 5 lesson/45 exercise. Test Android dùng repository xác định;
  bằng chứng backend thật được kiểm tra riêng, nên chưa tuyên bố gate onboarding liên thông.

## 12. Giai đoạn 5 — Daily learning loop và Home V2

### Mục tiêu

Biến Home thành điểm bắt đầu học hằng ngày có một hành động chính rõ ràng, tạo phiên
từ review đến hạn, điểm yếu và lesson tiếp theo; phiên ngắn vẫn dùng được với content
đã tải khi offline. Daily goal, streak, reminder và metric phải dựa trên policy/evidence
thay vì literal UI hoặc event do client tự khai báo không kiểm chứng.

### Phạm vi triển khai

1. Bổ sung policy engagement có version cho loại/giới hạn daily goal, quick-practice,
   review backlog và quiet hours; engagement status trả policy cùng goal progress độc
   lập với streak.
2. Chỉ cho streak/XP tăng từ event policy được phép và evidence canonical thuộc đúng
   learner; chống dùng nhiều client event ID cho cùng một evidence. Event start,
   completion và abandon của daily session được ghi để đo nhưng không tự tăng streak/XP.
3. Mở rộng reminder preference với quiet hours; backend kiểm tra timezone và giờ nhắc,
   mobile chỉ lập lịch sau consent/runtime permission, giữ denial state hiện có.
4. Thêm daily-session composer offline-first trên Flutter. Thứ tự là review đến hạn,
   concept yếu, lesson tiếp theo, rồi quick practice từ lesson đã cache/hoàn thành;
   backlog bị giới hạn theo policy nhưng tổng số vẫn hiển thị.
5. Home V2 có đúng một primary CTA kèm lý do, goal progress và streak là hai vùng riêng,
   trạng thái offline/sync minh bạch. Quick practice chọn 3–5 exercise canonical từ
   cùng lesson để tái sử dụng scorer, attempt, mastery và review hiện có.
6. Session summary nêu outcome, số lỗi cần ôn và bước tiếp theo; lifecycle start,
   completion, abandon và recommendation source được gửi bằng event không thưởng.

### Khu vực dự kiến thay đổi

- Backend: migration engagement policy, `EngagementService`/controller và integration test.
- Contract/tài liệu API: OpenAPI, `docs/reference/API_Check.md` và guide khi hành vi test tay đổi.
- Mobile: profile/engagement model, API service/view-model, daily-session model/composer,
  `HomeScreen`, recommendation card, learning view-model/summary, router/dependencies,
  localization và bộ test learner journey.
- Roadmap/process: `Ke_Hoach_2.md` và `Development_Change_Log.md` chỉ cập nhật `[x]`
  sau khi validation tương ứng pass.

### Validation

1. Backend targeted engagement/learning integration, full test, Modulith và `bootJar`.
2. OpenAPI lint, P0 release-freeze và đối chiếu controller/mobile consumer.
3. Dart format, `flutter gen-l10n`, analyzer, test composer/model/widget/offline cùng
   toàn bộ Flutter regression tích lũy.
4. Accessibility: text 200%, semantic label, touch target, light/dark theme và layout
   phone/landscape trong widget test; Android local debug APK và instrumentation nếu có target.
5. `git diff --check`, kiểm tra literal policy, event reward path và roadmap evidence.

### Giả định và rủi ro

- Giai đoạn 5 không xây practice-mode tổng quát của Giai đoạn 6; quick practice chỉ là
  lát cắt 3–5 exercise từ một lesson canonical để không nhân đôi content/scorer.
- Offline session chỉ cam kết trong lesson/unit đã cache. Metric có thể xếp hàng và đồng
  bộ sau; không biến trạng thái offline thành thành công server giả.
- Content-owner sign-off và onboarding → Unit 1 live gate của Giai đoạn 4 vẫn độc lập,
  không được đóng gián tiếp bởi Home V2.

### Phê duyệt

Developer phê duyệt thực hiện ngày 2026-08-02 bằng yêu cầu triển khai toàn bộ Giai đoạn 5
theo `docs/plans/Ke_Hoach_2.md`.

## 13. Giai đoạn 6 — Practice modes dùng lại content

### Mục tiêu

Tạo sáu chế độ luyện chủ động từ lesson/exercise canonical đã publish, giữ nguyên scorer,
attempt, mastery và review hiện có nhưng tách rõ practice evidence khỏi curriculum progress.
Learner chọn được phạm vi unit/lesson/concept, nhận lý do chọn nội dung và vẫn có fallback
giới hạn khi chỉ còn content đã cache.

### Phạm vi triển khai

1. Chuẩn hóa `practiceMode` trong attempt evidence cho daily quick practice, flashcards,
   adaptive learn, practice test, match, mistakes và weak concepts. Backend vẫn phát
   `AttemptAccepted` cho mastery/review nhưng loại mọi practice attempt khỏi phép tính
   lesson/course completion.
2. Thêm selector thuần, deterministic theo mode/scope/count/type, mastery, review đến hạn và
   lịch sử lỗi. Selection giữ tham chiếu exercise cùng source lesson/version; không tạo bản
   sao content hay scorer.
3. Lưu kết quả attempt tối thiểu trong SQLite để chọn lỗi gần đây. Query dùng trạng thái mới
   nhất của mỗi exercise, có giới hạn và làm nguồn offline; content vẫn chỉ được lấy từ cache
   lesson/unit hiện có.
4. Mở Practice Hub từ Home với sáu mode. Practice Test cấu hình số câu/type; learner chọn
   unit/lesson/concept; màn hình giải thích vì sao nội dung được chọn và thông báo fallback.
5. Mở rộng learning flow cho practice nhiều lesson, summary điểm đúng/sai và evidence mode.
   Flashcard có nút lật, xáo, phát audio khi canonical exercise có media, biết/chưa biết;
   Match dùng control chọn cặp và không dùng thời gian làm tín hiệu mastery duy nhất.
6. Dùng control Material native, semantic/live region, text theme co giãn và vùng chạm tối
   thiểu 48dp; không mode nào bắt buộc swipe, gesture ẩn hoặc giới hạn thời gian.

### Khu vực dự kiến thay đổi

- Backend learning service và integration test.
- OpenAPI cùng `docs/reference/API_Check.md`, `docs/shared/Guide.md`.
- Mobile learning model/repository/view-model/renderer, SQLite, practice feature, Home/router,
  localization và test deterministic/offline/widget.
- Roadmap/process chỉ được đánh dấu hoàn tất sau khi validation tương ứng pass.

### Validation

1. Backend learning integration chứng minh practice cập nhật mastery/review nhưng progress và
   completion không đổi; invalid mode bị từ chối. Sau đó chạy full backend test và `bootJar`.
2. OpenAPI lint và đối chiếu enum evidence giữa contract, Java và Dart.
3. Dart format, `flutter gen-l10n`, analyzer, targeted selector/database/widget test và full
   Flutter regression tích lũy.
4. Widget accessibility ở text scaling 200%, semantic labels, touch target; build debug APK và
   Android integration test khi có emulator/device khả dụng.
5. `git diff --check`, rà soát không copy canonical data, không answer leakage và cập nhật
   roadmap/change log theo bằng chứng thực tế.

### Giả định và rủi ro

- Audio practice dùng metadata/media endpoint canonical hiện có. Khi media chưa cache và mất
  mạng, transcript/silent path là fallback; không coi phát audio là điều kiện bắt buộc để trả lời.
- Mistakes offline chỉ phản ánh attempt đã nhận được feedback và lưu local; attempt còn trong
  outbox chưa có kết quả server nên không được đoán đúng/sai.
- Adaptive Learn giai đoạn này dùng mastery/review evidence hiện có để chuyển recognition sang
  recall; không thêm mô hình ML hoặc công thức mastery riêng trên client.

### Phê duyệt

Developer phê duyệt thực hiện ngày 2026-08-02 bằng yêu cầu triển khai toàn bộ Giai đoạn 6
theo `docs/plans/Ke_Hoach_2.md`.

### Kết quả

- Practice Hub cung cấp đủ sáu mode, scope unit/lesson/concept, giới hạn câu/type, lý do
  selection và fallback offline. Flashcard dùng nút lật/xáo/audio và biết/chưa biết; summary
  dùng score của phiên thay vì biến practice thành course progress.
- Selector giữ tham chiếu exercise/source lesson/version canonical; deterministic test chứng
  minh một object dùng qua ba mode và Adaptive Learn đổi recognition→recall theo mastery.
- SQLite V3 lưu outcome mới nhất để chọn lỗi gần đây. Attempt có `practiceMode` thống nhất;
  backend vẫn cập nhật mastery/review nhưng lọc khỏi progress và learning completion.
- Learning API targeted 9/9, full backend regression và `bootJar`, OpenAPI lint/P0 freeze,
  Flutter analyzer, 61/61 mobile test và local debug APK đều pass. Không có Android target
  trong `flutter devices`, vì vậy device E2E không được ghi nhận trong lượt này.

## 14. Giai đoạn 7 — Hoàn thiện course A1

### Mục tiêu

Mở rộng vertical slice Unit 1 thành course English A1 version 3 gồm 4 unit/20 lesson
learner-safe, có guidebook/checkpoint, progression và evidence đa kỹ năng đủ cho closed beta;
đồng thời khóa chính sách placement start point, version migration, completion assessment và
full-course offline package bằng contract có version thay vì literal phía client.

### Phạm vi triển khai

1. Mở rộng content schema/pipeline cho unit guidebook, completion assessment đa kỹ năng,
   placement start points, version migration và offline package policy. Validator kiểm tra đủ
   4 unit/20 lesson, checkpoint cuối mỗi unit, recurrence/prerequisite, skill coverage,
   media/accessibility và `non_accredited_completion`.
2. Tạo generator course A1 version 3 từ curriculum map: 20 lesson × 9 exercise canonical,
   4 checkpoint, guidebook EN/VI, advanced speaking/writing/conversation activities và media
   WAV có transcript/checksum/provenance/silent path. Sinh learner preview và admin fixture.
3. Mở rộng backend content DTO/persistence/delivery để giữ policy/guidebook learner-safe;
   integration test publish full course, chấm 180/180 exercise, xác nhận 20 lesson, mastery,
   review, completion progress và policy migration.
4. Mở rộng placement assessment bằng start-point policy theo score. Response trả recommended
   point cùng các điểm thấp hơn được phép; mobile cho learner chọn trực tiếp nhưng không tự
   đánh dấu lesson cũ hoàn thành hay cấp chứng chỉ được công nhận.
5. Mobile hiển thị guidebook theo unit, policy offline/version/size và hành động tải toàn course
   qua cache lesson/version hiện có. Summary course hoàn tất nhắc rõ A1 completion nội bộ,
   `non-accredited`.
6. Bổ sung content/backend/mobile/Android test surface cho full course và cập nhật tài liệu vận
   hành, API, roadmap, change log theo bằng chứng thực tế.

### Khu vực dự kiến thay đổi

- `contracts/schema/`, OpenAPI và content pipeline/test.
- `content/courses/course-en-for-vi/course-a1-v3/`, generator/media tooling và tài liệu content.
- Backend curriculum/assessment, Flyway V15, admin fixture và integration test.
- Mobile learning/placement model, repository, view-model, path UI, localization và test.
- `API_Check.md`, `Guide.md`, mobile/content README, roadmap và change log.

### Validation

1. JSON Schema + semantic content validator, generated preview answer-leak audit, media binary
   checksum/duration/provenance và deterministic regeneration.
2. Backend targeted curriculum/assessment integration trên PostgreSQL, full regression,
   Spring Modulith và `bootJar`.
3. OpenAPI Redocly lint, P0 freeze và compatibility review cho field bổ sung.
4. Flutter gen-l10n/format/analyzer, targeted content-model/offline/placement/path tests và full
   mobile regression; build debug APK.
5. Android full-course integration khi có target; nếu không có target thì giữ gate closed và
   ghi chính xác blocker. Cuối cùng chạy `git diff --check` và rà soát learner-safe output.

### Giả định và rủi ro

- Course version 3 giữ `compatibilityVersion = 2` với Unit 1 V2. Learner ở version 2 giữ
  mastery/progress tương thích; version 1 được xử lý theo policy `require_restart` vì semantics
  đã thay đổi.
- TTS local tạo binary kỹ thuật có provenance nhưng không thay thế language/pedagogy/cultural
  review của content owner; checkbox review con người chỉ đóng khi có sign-off thật.
- Placement start point là recommendation điều hướng, không tự hoàn thành lesson trước đó.
  Learner luôn có thể chọn điểm thấp hơn; completion course vẫn yêu cầu evidence của curriculum.
- Android closed-testing completion là gate môi trường/người dùng thật và không được suy diễn
  từ backend, widget test hoặc APK build.

### Phê duyệt

Developer phê duyệt thực hiện ngày 2026-08-02 bằng yêu cầu triển khai toàn bộ Giai đoạn 7
theo `docs/plans/Ke_Hoach_2.md`.

### Kết quả

- Course A1 v3 được sinh xác định từ curriculum map: 4 unit/20 lesson/180 exercise, 4
  guidebook/checkpoint, 40 WAV và learner-safe preview. Recurrence xuất hiện trong nội dung
  comprehension/checkpoint; evidence gồm listening 40, reading 40, writing 20 và 20 activity
  pronunciation cùng writing/conversation ở checkpoint.
- Backend giữ/deliver guidebook và bốn policy course, integration publish full fixture và kiểm
  tra 20 lesson/180 exercise cùng answer stripping. Compatibility version 2 tiếp tục dùng cơ
  chế versioned curriculum hiện có; policy mô tả version không tương thích là restart.
- Mobile hiển thị guidebook, tải toàn course theo package v3/64 MB/TTL 30 ngày và gọi media
  downloader thật, placement xếp điểm đề xuất trước nhưng giữ mọi mức thấp hơn, completion ghi
  rõ non-accredited.
- Content pipeline 10/10, backend full regression và `bootJar`, Redocly/P0 freeze, Flutter
  analyzer và full mobile suite cuối 63/63 đều pass; targeted media/placement/offline 22/22 pass.
  Local debug APK build pass; không có Android target nên closed-testing E2E và
  content-owner sign-off vẫn là gate mở.
