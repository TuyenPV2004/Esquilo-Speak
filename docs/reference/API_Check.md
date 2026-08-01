# API Check — EsquiloSpeak

## 1. Mục đích

Tài liệu này giúp developer và tester biết:

- API nào đang có trong hệ thống.
- API dùng để làm gì và xuất hiện ở bước nào của nghiệp vụ.
- API cần loại xác thực nào.
- Khi thao tác trên app thì nên tìm request nào trong Network hoặc backend log.
- Những điểm nào đã có trong contract nhưng mobile chưa sử dụng đầy đủ.

Nguồn chuẩn có thể đọc bằng máy là
[`contracts/openapi/esquilospeak-learning-v1.yaml`](../../contracts/openapi/esquilospeak-learning-v1.yaml).
File này là bản giải thích dễ đọc cho con người, không thay thế OpenAPI.

## 2. Quy ước chung

| Nội dung | Quy ước |
|---|---|
| Base URL backend local | `http://localhost:8080` trên máy tính |
| Android Emulator | Mặc định dùng `http://10.0.2.2:8080` |
| ADB reverse | Dùng `http://127.0.0.1:8080` sau khi chạy `adb reverse tcp:8080 tcp:8080` |
| API công khai | Năm nhóm API catalog không cần token: languages, courses, course lessons, advanced activities và lesson detail |
| API learner | Cần Bearer JWT có role `LEARNER` và scope `learning` |
| API content admin | Cần scope `content` và role `CONTENT_STAFF` hoặc `ADMIN` |
| API support staff | Cần scope `operations` và role `SUPPORT` hoặc `ADMIN` |
| Theo dõi request | Có thể gửi `X-Correlation-ID`; backend trả correlation ID để đối chiếu app log với backend log |
| Chống gửi trùng | Các API có ghi `Idempotency-Key` phải dùng lại cùng key khi retry cùng một request; không tái sử dụng key cho payload khác |
| Lỗi API | Lỗi chuẩn dùng `application/problem+json`; khi báo lỗi nên giữ status, error code và correlation ID nhưng loại bỏ token/dữ liệu nhạy cảm |

### 2.1. Quy ước locale và nội dung trình bày

- `uiLocale` là ngôn ngữ giao diện; `sourceLanguage` là ngôn ngữ người học hiểu;
  `targetLanguage` là ngôn ngữ đang học. Ba giá trị có vai trò độc lập.
- Locale truyền qua API dùng BCP 47 language tag. Client ưu tiên exact tag, sau
  đó language match, rồi `defaultLocale` của chính entity; không có fallback
  toàn cục cố định sang tiếng Anh.
- Course, lesson, placement question/option, concept và achievement trả
  `LocalizedText`. Placement option dùng `id` ổn định để chấm, không gửi lại text.
- Attempt feedback và advanced feedback trả stable message `code`; mobile ánh xạ
  code sang ARB của ngôn ngữ giao diện. Parameters chỉ chứa dữ liệu để định dạng.
- Trạng thái support/privacy là domain code; mobile đổi sang nhãn đã dịch trước
  khi hiển thị.

Căn cứ kỹ thuật: [Flutter internationalization](https://docs.flutter.dev/ui/internationalization),
[Android localization](https://developer.android.com/guide/topics/resources/localization),
[Unicode Locale Identifiers and matching](https://www.unicode.org/reports/tr35/tr35.html),
[Dart `DateFormat`](https://api.flutter.dev/flutter/package-intl_intl/DateFormat-class.html)
và [`NumberFormat`](https://api.flutter.dev/flutter/package-intl_intl/NumberFormat-class.html).

Trong môi trường local, app lấy guest JWT từ `POST /internal/dev/token`. Endpoint này chỉ
phục vụ phát triển, không được xem là API production.

## 3. Luồng nghiệp vụ chính

### 3.1. Mở app và onboarding

1. App local lấy guest JWT qua `POST /internal/dev/token`.
2. App tải languages, profile, consent, mastery, review và engagement; placement
   được tải sau khi có khóa học đang chọn.
3. Người dùng chọn source language, target language và một course đã xuất bản;
   `PUT /me/profile` lưu cặp ngôn ngữ cùng `activeCourseId` sau khi backend đối
   chiếu catalog.
4. Các lựa chọn consent được lưu qua `PUT /me/consents/{purpose}`.
5. App tải danh sách khóa học và bài học để vào hành trình học.

### 3.2. Học một bài và đồng bộ tiến độ

1. `GET /courses` lấy khóa học theo cặp ngôn ngữ.
2. `GET /courses/{courseId}/lessons` lấy danh sách bài cùng `unitId`, `unitTitle` và
   `position` để client dựng learning path và manifest tải offline theo unit.
3. `GET /lessons/{lessonId}` lấy nội dung phiên bản bài học đã xuất bản.
4. Khi người dùng trả lời, app hiện tại ưu tiên lưu mutation local để vẫn hoạt động khi
   offline.
5. Khi có mạng, `POST /sync/push` gửi các mutation `attempt.submit`; sau đó
   `GET /sync/pull` kéo trạng thái chuẩn từ server.
6. `GET /progress/courses/{courseId}`, `GET /mastery` và `GET /reviews` hiển thị tiến độ,
   độ thành thạo và lịch ôn tập.

`POST /attempts` vẫn là API nộp một attempt trực tiếp. Tuy nhiên luồng mobile hiện tại chủ
yếu dùng hàng đợi offline và `sync/push` để tránh mất bài khi mạng không ổn định.

### 3.3. Học nâng cao

1. `GET /media/{mediaId}` tải audio học tập có xác thực.
2. `POST /advanced/pronunciation` chấm mẫu phát âm ngắn và không lưu giọng nói thô.
3. `POST /advanced/writing` trả phản hồi bài viết đã qua bộ lọc an toàn.
4. `POST /advanced/conversation` tiếp tục hội thoại có hướng dẫn và bộ lọc an toàn.

### 3.4. Placement và engagement

1. `GET /assessments/placement?courseId={courseId}` tải bài xếp trình độ nội bộ
   gắn với framework/version/level của khóa học.
2. `POST /assessments/placement/attempts` gửi `assessmentId`, chấm bài và tạo completion record không phải
   chứng chỉ được công nhận.
3. `GET /engagement` tải streak, XP, achievement và cấu hình nhắc học.
4. Hoạt động học được ghi qua `POST /engagement/activities`.
5. Người dùng đổi nhắc học qua `PUT /engagement/notification-preference`; lịch nhắc thực
   tế được thiết bị Android xử lý local.

### 3.5. Premium, hỗ trợ và quyền riêng tư

- Premium: verify giao dịch, đọc entitlement từ server, rồi revoke entitlement khi refund.
- Hỗ trợ: learner tạo/xem ticket; support staff đổi trạng thái ticket.
- Quyền riêng tư: learner yêu cầu export hoặc deletion, sau đó đọc trạng thái xử lý.
- Chuyển guest thành account: tạo merge ticket một lần rồi merge dữ liệu học bằng tài
  khoản đã đăng nhập.

## 4. Danh sách API

### 4.1. Local authentication

| Method và path | Operation | Tác dụng | Nghiệp vụ và lưu ý |
|---|---|---|---|
| `POST /internal/dev/token` | Local only | Cấp guest JWT để chạy app local | Không cần token đầu vào; chỉ có ở profile local, không dùng production |

### 4.2. Catalog và học tập cốt lõi

| Method và path | Operation ID | Tác dụng | Nghiệp vụ và lưu ý |
|---|---|---|---|
| `GET /api/mobile/v1/languages` | `listLearningLanguages` | Lấy ngôn ngữ học đang bật | Mở app/onboarding; công khai |
| `GET /api/mobile/v1/courses` | `listCourses` | Lấy khóa học đã xuất bản theo `sourceLanguage` và `targetLanguage`, gồm proficiency framework cùng entry/target level | Chọn khóa học; công khai |
| `GET /api/mobile/v1/courses/{courseId}/lessons` | `listCourseLessons` | Lấy các bài đã xuất bản theo thứ tự khóa học | Mở danh sách bài; công khai |
| `GET /api/mobile/v1/lessons/{lessonId}` | `getLesson` | Lấy nội dung bất biến của một phiên bản bài | Vào màn hình học; công khai |
| `POST /api/mobile/v1/attempts` | `submitAttempt` | Gửi một câu trả lời dạng append-only | Cần learner JWT và `Idempotency-Key`; server còn khử trùng theo `clientAttemptId` |
| `GET /api/mobile/v1/progress/courses/{courseId}` | `getCourseProgress` | Lấy tiến độ chuẩn của learner trong khóa học | Làm mới tiến độ sau học/đồng bộ; cần learner JWT |
| `POST /api/mobile/v1/learning-sessions` | `startLearningSession` | Mở một phiên học gắn với phiên bản nội dung | Cần learner JWT và `Idempotency-Key`; mobile hiện chưa gọi trong hành trình học chính |
| `POST /api/mobile/v1/learning-sessions/{sessionId}/completion` | `completeLearningSession` | Đánh dấu phiên học hoàn tất theo cách idempotent | Cần learner JWT; mobile hiện chưa gọi trong hành trình học chính |

### 4.3. Mastery, review và offline sync

| Method và path | Operation ID | Tác dụng | Nghiệp vụ và lưu ý |
|---|---|---|---|
| `GET /api/mobile/v1/mastery` | `listMasteryStates` | Lấy mastery có phiên bản và giải thích được | Preload khi mở app và màn Review; cần learner JWT |
| `GET /api/mobile/v1/reviews` | `listDueReviews` | Lấy các mục đến hạn ôn theo giờ server | Preload/màn Review; cần learner JWT |
| `POST /api/mobile/v1/sync/push` | `pushOfflineMutations` | Đẩy batch mutation offline theo thứ tự, có thể retry an toàn | Luồng nộp bài offline-first; cần learner JWT; xung đột payload trùng ID trả `409` |
| `GET /api/mobile/v1/sync/pull` | `pullLearningChanges` | Kéo thay đổi chuẩn sau một cursor | Chạy sau push hoặc khi nối mạng lại; cần learner JWT |

### 4.4. Hồ sơ, consent, identity và privacy

| Method và path | Operation ID | Tác dụng | Nghiệp vụ và lưu ý |
|---|---|---|---|
| `GET /api/mobile/v1/me/profile` | `getLearnerProfile` | Lấy hồ sơ guest/account và learning context hiện tại | Hồ sơ mới có thể chưa có locale/source/target/active course; preload và màn Profile; cần learner JWT |
| `PUT /api/mobile/v1/me/profile` | `replaceLearnerProfile` | Hoàn thành hoặc thay thế hồ sơ/onboarding | Bắt buộc `uiLocale`, source/target khác nhau, `activeCourseId`, age band; backend chỉ nhận language đang bật và course đã publish đúng cặp; cần learner JWT |
| `GET /api/mobile/v1/me/consents` | `listCurrentConsents` | Lấy quyết định mới nhất của từng consent purpose | Preload và màn Profile; cần learner JWT |
| `PUT /api/mobile/v1/me/consents/{purpose}` | `recordConsent` | Ghi thêm một quyết định consent có version | Bật/tắt consent; cần learner JWT |
| `POST /api/mobile/v1/me/guest-merge-tickets` | `createGuestMergeTicket` | Tạo ticket một lần, tồn tại ngắn để chuyển guest | Bước đầu của luồng nâng cấp account; cần JWT của guest |
| `POST /api/mobile/v1/me/guest-merges` | `mergeGuestIntoAccount` | Gộp dữ liệu học guest vào account hiện tại | Cần JWT account và `Idempotency-Key`; phụ thuộc OIDC account flow |
| `POST /api/mobile/v1/me/privacy/exports` | `requestAccountExport` | Yêu cầu export dữ liệu dạng máy đọc bất đồng bộ | Trả `202`; cần learner JWT và `Idempotency-Key` |
| `POST /api/mobile/v1/me/privacy/deletions` | `requestAccountDeletion` | Yêu cầu xóa account và hạn chế learner ngay | Trả `202`; cần learner JWT và `Idempotency-Key` |
| `GET /api/mobile/v1/me/privacy/requests/{requestId}` | `getPrivacyRequest` | Đọc trạng thái privacy request thuộc learner hiện tại | Theo dõi export/deletion; cần learner JWT |

### 4.5. Quản trị nội dung

| Method và path | Operation ID | Tác dụng | Nghiệp vụ và lưu ý |
|---|---|---|---|
| `PUT /api/admin/v1/content/courses/{courseId}/versions/{version}` | `saveCourseVersionDraft` | Tạo hoặc thay thế bản nháp khóa học | Payload bắt buộc có proficiency framework/version và entry/target level hợp lệ; chỉ draft được thay; cần content scope và content staff/admin |
| `GET /api/admin/v1/content/courses/{courseId}/versions/{version}` | `getCourseVersionAuthoring` | Xem trước dữ liệu authoring của một version | Có thể chứa scoring answers, không trả qua learner API; cần quyền content |
| `POST /api/admin/v1/content/courses/{courseId}/versions/{version}/transitions` | `transitionCourseVersion` | Chuyển trạng thái draft → review → approved → scheduled/published → retired | Khi vào review bắt buộc gửi đủ `reviewEvidence` có version; backend lưu evidence vào audit trail; cần quyền content |
| `POST /api/admin/v1/content/courses/{courseId}/rollbacks` | `rollbackCourseVersion` | Khôi phục một version từng published rồi retired | Luồng rollback nội dung; cần quyền content |

### 4.6. Media và học nâng cao

| Method và path | Operation ID | Tác dụng | Nghiệp vụ và lưu ý |
|---|---|---|---|
| `GET /api/mobile/v1/media/{mediaId}` | `getLearningMedia` | Stream file media học tập | Tải audio vào vùng lưu trữ riêng của app; cần learner JWT |
| `POST /api/mobile/v1/advanced/pronunciation` | `assessPronunciation` | Chấm mẫu phát âm ngắn | Không lưu raw voice; cần learner JWT |
| `POST /api/mobile/v1/advanced/writing` | `getWritingFeedback` | Phản hồi bài viết qua safety filter | Màn Writing; cần learner JWT |
| `POST /api/mobile/v1/advanced/conversation` | `getConversationFeedback` | Phản hồi hội thoại có hướng dẫn qua safety filter | Màn Conversation; cần learner JWT |

### 4.7. Assessment và engagement

| Method và path | Operation ID | Tác dụng | Nghiệp vụ và lưu ý |
|---|---|---|---|
| `GET /api/mobile/v1/assessments/placement?courseId={courseId}` | `getPlacementAssessment` | Lấy bài placement của khóa học cùng proficiency reference | Màn Placement sau khi chọn khóa học; cần learner JWT |
| `POST /api/mobile/v1/assessments/placement/attempts` | `submitPlacementAssessment` | Chấm placement theo `assessmentId` và giữ framework/version/level trong evidence | Không phải chứng chỉ được công nhận; cần learner JWT và `Idempotency-Key` |
| `GET /api/mobile/v1/engagement` | `getEngagementStatus` | Lấy streak, XP, achievement và reminder preference | Preload/màn Engagement; cần learner JWT |
| `POST /api/mobile/v1/engagement/activities` | `recordEngagementActivity` | Ghi một hoạt động học idempotent | Cập nhật XP/streak/achievement; cần learner JWT |
| `PUT /api/mobile/v1/engagement/notification-preference` | `updateNotificationPreference` | Lưu cấu hình nhắc học | Server lưu preference, Android lập lịch local; cần learner JWT |

### 4.8. Commerce

| Method và path | Operation ID | Tác dụng | Nghiệp vụ và lưu ý |
|---|---|---|---|
| `GET /api/mobile/v1/commerce/entitlements` | `listEntitlements` | Lấy entitlement chuẩn từ server | Dùng để khôi phục trạng thái premium; cần learner JWT |
| `POST /api/mobile/v1/commerce/purchases/verify` | `verifyPurchase` | Xác minh Play purchase và cấp entitlement | Chỉ lưu token hash; cần learner JWT |
| `POST /api/mobile/v1/commerce/purchases/refund` | `verifyRefund` | Xác minh refund và thu hồi entitlement | Cần learner JWT |

### 4.9. Support

| Method và path | Operation ID | Tác dụng | Nghiệp vụ và lưu ý |
|---|---|---|---|
| `GET /api/mobile/v1/support/tickets` | `listOwnSupportTickets` | Lấy ticket hỗ trợ/content report của learner | Màn lịch sử hỗ trợ; cần learner JWT |
| `POST /api/mobile/v1/support/tickets` | `createSupportTicket` | Tạo yêu cầu hỗ trợ hoặc báo cáo nội dung | Màn Support; cần learner JWT |
| `PATCH /api/support/v1/tickets/{ticketId}/status` | `updateSupportTicketStatus` | Phân loại, xử lý hoặc đóng ticket | Chỉ support staff/admin có operations scope |

## 5. Điểm cần lưu ý khi kiểm thử

1. Nếu thao tác chỉ thay đổi UI, chuyển tab, validate form hoặc lập lịch notification local
   thì có thể không xuất hiện request mới.
2. Khi học offline, request có thể chỉ xuất hiện sau khi thiết bị có mạng lại; tìm
   `POST /sync/push` rồi `GET /sync/pull`.
3. Mở app lần đầu thường có nhiều API preload chạy gần nhau. Dùng method, path và
   correlation ID để ghép đúng request với backend log.
4. `GET /commerce/entitlements` có trong contract nhưng view model premium hiện chưa gọi
   lại API này khi mở màn hình; trạng thái đang dựa vào kết quả verify/refund trong phiên.
5. Learning session API và guest merge API đã có contract/backend nhưng chưa nằm trong
   hành trình mobile local chính.
6. Không đưa Bearer token, purchase token, nội dung giọng nói, thông tin cá nhân hoặc dữ
   liệu consent thật vào ảnh/log báo lỗi.

Ma trận thao tác kiểm thử A01–O04 và API mong đợi nằm trong
[`Guide.md`](../shared/Guide.md#6-danh-sách-nghiệp-vụ-cần-kiểm-thử).

## 6. Thay đổi contract loại bỏ hardcode

- `GET /api/mobile/v1/courses/{courseId}/advanced-activities` trả activity definition đã publish, gồm media ID, content reference, expected input, target locale và feedback locale. UI không fallback sang nội dung A1 cố định.
- Attempt mới gửi `response` có discriminator; `selectedOptionId` chỉ còn là adapter tương thích cho outbox cũ.
- Exercise Engine V2 dùng các response kind `option`, `boolean`, `self_assessment`,
  `pairs`, `sequence` và `text`. Attempt gửi thêm `evidence` độc lập renderer gồm
  response time, hint, retry, confidence và input modality; server lưu evidence và
  quyết định correctness theo content version canonical.
- `POST /api/mobile/v1/engagement/activities` nhận `eventType` và `evidenceRef`; server chọn XP theo policy version thay vì tin điểm do client gửi.
- `PUT /api/mobile/v1/engagement/notification-preference` nhận giờ, locale và IANA timezone; streak được tính theo ngày học tại timezone đó.
- Profile trước onboarding có thể chưa có locale/cặp ngôn ngữ/course. `PUT /me/profile` bắt buộc active course đã publish và khớp source/target.
- Placement trả `defaultLocale`, prompt/option đa locale và stable option ID.
  Attempt chỉ gửi option ID.
- Attempt feedback trả `messageCode`; advanced feedback trả `code`, `parameters`
  và `locale`, không trả câu tiếng Anh dùng trực tiếp làm UI.
- Mastery/review/achievement trả title/description đa locale để client không hiện
  raw concept hoặc achievement code trong luồng thông thường.

## 7. Checklist khi chỉnh sửa API

- [ ] Cập nhật OpenAPI nếu method, path, parameter, header, request/response, status hoặc
      error contract thay đổi.
- [ ] Cập nhật backend controller/service/security/rate limit liên quan.
- [ ] Cập nhật mobile API client, model và luồng UI liên quan.
- [ ] Cập nhật bảng API, luồng nghiệp vụ và lưu ý kiểm thử trong file này.
- [ ] Cập nhật API tương ứng trong `Guide.md` nếu thay đổi ảnh hưởng ma trận kiểm thử tay.
- [ ] Chạy contract lint/test, backend test và mobile test phù hợp với phạm vi thay đổi.
- [ ] Tìm path cũ trong repository để tránh OpenAPI, backend, mobile và tài liệu bị lệch.
- [ ] Kiểm tra log/tài liệu không chứa secret, token hoặc dữ liệu cá nhân.
