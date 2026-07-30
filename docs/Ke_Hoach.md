# Kế hoạch xây dựng EsquiloSpeak cho Android

> Trạng thái tài liệu: **Đang thực thi**  
> Cập nhật gần nhất: **2026-07-30**
> Mục tiêu phát hành hiện tại: **Android**  
> Thứ tự triển khai: **hoàn thiện backend của phạm vi được duyệt trước, sau đó triển khai Android frontend**  
> Ngoài phạm vi hiện tại: **native iOS build, test và release**

## 1. Mục đích

Tài liệu này là roadmap thực thi chi tiết của EsquiloSpeak. Nó trả lời bốn câu
hỏi:

1. Repository đã làm được gì và bằng chứng nằm ở đâu?
2. Hạng mục nào phải làm tiếp theo và phụ thuộc vào hạng mục nào?
3. Khi nào backend đủ điều kiện bàn giao cho Android frontend?
4. Cần kiểm tra gì trước khi một hạng mục được đánh dấu hoàn thành?

Đây là kế hoạch sống, không thay thế:

- [phạm vi và quyết định sản phẩm](Project.md);
- [mô tả nghiệp vụ hoàn chỉnh](Nghiep_Vu.md);
- [tech stack và kiến trúc](Tech_Stack_And_Architecture.md);
- [cấu trúc repository](Repository_Structure.md);
- các [ADR đã được chấp nhận](Adr_002_Foundation_And_First_Learning_Slice.md);
- OpenAPI và JSON Schema trong [`contracts/`](../contracts/).

Kế hoạch này cụ thể hóa các nguồn trên thành thứ tự triển khai và checklist.
Thứ tự là quyết định của project, được suy ra từ dependency hiện tại; không phải
là một quy trình bắt buộc của Flutter hay Spring.

## 2. Quy ước trạng thái

- `[x]`: đã có artifact hoặc implementation trong repo và có bằng chứng
  validation phù hợp.
- `[ ]`: chưa làm, mới làm một phần hoặc chưa có đủ bằng chứng kiểm tra.
- Hạng mục làm một phần phải giữ `[ ]` và mô tả rõ phần còn thiếu.
- Không đánh dấu cả giai đoạn hoàn thành nếu còn quality gate bắt buộc chưa đạt.

Mức ưu tiên:

- **P0:** bắt buộc cho bản Android đầu tiên có thể phát hành.
- **P1:** cần cho sản phẩm học tập hoàn chỉnh sau nền tảng P0.
- **P2:** năng lực mở rộng, chỉ triển khai sau khi P0/P1 và dữ liệu thực tế chứng
  minh nhu cầu.

## 3. Nguyên tắc thực thi

1. **Android-first:** hiện tại chỉ build, test và chuẩn bị phát hành Android.
   Shared Flutter code có thể giữ khả năng mở rộng, nhưng không dùng thời gian
   cho native iOS.
2. **Backend-first:** sau phần vertical slice đã có, mỗi phạm vi mới phải hoàn
   thành contract, dữ liệu, backend, security và backend tests trước khi xây
   Android UI tương ứng.
3. **Contract-first tại boundary:** thay đổi client API phải bắt đầu từ OpenAPI
   và schema; chỉ tăng API major version khi có breaking change không thể tương
   thích.
4. **Modular monolith trước:** mở rộng module nghiệp vụ trong một Spring Boot
   deployable; không tự tách microservice, broker, Redis hoặc Kubernetes.
5. **Offline và accessibility là yêu cầu nền tảng:** không để đến cuối release
   mới xử lý.
6. **Bảo mật theo rủi ro:** backend tham chiếu OWASP ASVS; Android tham chiếu
   OWASP MASVS/MASTG. Không lưu production secret trong repo.
7. **Kiểm thử tích lũy:** test mới bổ sung vào bộ test cũ; không làm yếu test cũ
   để thay đổi mới pass.
8. **Dữ liệu đo lường có mục đích:** chỉ thu thập event cần cho learning outcome,
   reliability và product decision; phải có privacy inventory và retention.

## 4. Definition of Ready và Definition of Done

### 4.1 Backend scope sẵn sàng để triển khai

- [ ] Nghiệp vụ, actor, happy path, error path và invariant đã được chốt.
- [ ] API/event contract và dữ liệu ownership đã rõ.
- [ ] Quyết định privacy, retention, authorization và idempotency đã rõ.
- [ ] Acceptance criteria có thể kiểm thử.
- [ ] Không còn câu hỏi P0 làm thay đổi đáng kể model hoặc public contract.

### 4.2 Backend scope hoàn thành

- [ ] OpenAPI/schema lint pass và có backward-compatibility review.
- [ ] Migration chạy được trên PostgreSQL thật hoặc Testcontainers.
- [ ] Unit, integration, security và Spring Modulith boundary tests pass.
- [ ] Error contract, idempotency, audit và observability phù hợp với mutation.
- [ ] Không trả dữ liệu nhạy cảm hoặc đáp án trước thời điểm nghiệp vụ cho phép.
- [ ] Hướng dẫn chạy local và cấu hình production đã cập nhật.
- [ ] CI chạy lại toàn bộ regression suite liên quan.

### 4.3 Android scope hoàn thành

- [ ] UI có loading, empty, success, validation, retry và failure states.
- [ ] ViewModel/Repository/Service có boundary rõ và có test.
- [ ] Dữ liệu nhạy cảm dùng storage phù hợp; log không chứa token hoặc PII.
- [ ] Offline/reconnect có hành vi rõ, không âm thầm làm mất attempt.
- [ ] Accessibility, localization tiếng Việt/Anh và nhiều kích thước màn hình
  được kiểm tra.
- [ ] Widget/integration tests pass; APK release build được.
- [ ] Luồng thật Android ↔ backend ↔ PostgreSQL được kiểm tra end-to-end.

## 5. Trạng thái đã thực hiện và cần review lại

### Giai đoạn 0 — Discovery, sản phẩm và nghiệp vụ

Mục tiêu: biết sản phẩm giải quyết vấn đề gì, dành cho ai và có những nghiệp vụ
nào trước khi tiếp tục mở rộng implementation.

- [x] Có product scope, persona, core learning loop và lộ trình cấp cao trong
  [Project.md](Project.md).
- [x] Có mô tả nghiệp vụ mục tiêu từ identity, curriculum, learning, mastery,
  offline đến commerce, operations và analytics trong
  [Nghiep_Vu.md](Nghiep_Vu.md).
- [x] Có tech stack/architecture và điều kiện tiến hóa trong
  [Tech_Stack_And_Architecture.md](Tech_Stack_And_Architecture.md).
- [x] Có cấu trúc repo và dependency rule trong
  [Repository_Structure.md](Repository_Structure.md).
- [x] Chốt thị trường, source/target language và nhóm tuổi cho bản Android đầu
  tiên.
- [x] Chốt guest/account merge, consent theo độ tuổi và voice retention.
- [x] Chốt success metric, SLO, support policy và phạm vi subscription P0.

Điều kiện qua giai đoạn: các câu hỏi P0 ảnh hưởng identity, content và privacy
phải được chốt trước khi khóa contract backend tương ứng.

### Giai đoạn 1 — Contract và quyết định kỹ thuật đầu tiên

- [x] Có JSON Schema cho language, course, lesson và learner lesson delivery.
- [x] Learner delivery schema không lộ `correctOptionId`/`explanation` trước
  attempt.
- [x] Có OpenAPI cho catalog, lessons, attempt, feedback và course progress.
- [x] Có ADR-002 ghi nhận Foundation và vertical slice đầu tiên.
- [x] Contract được lint bằng Redocly và JSON được parse trong CI.
- [ ] Bổ sung automated breaking-change check giữa contract hiện tại và
  baseline phát hành gần nhất.
- [ ] Chốt error envelope dùng chung, pagination, trace ID và retry metadata cho
  các endpoint tiếp theo.

### Giai đoạn 2 — Foundation Sprint Flutter và Spring Boot

- [x] Có root configuration, ignore, cấu hình mẫu và README hướng dẫn local.
- [x] Có Flutter `3.44.3`/Dart `3.12.2` skeleton và cấu trúc
  View–ViewModel–Repository–Service.
- [x] Có Android Gradle project và đã build APK trong lần validation Foundation.
- [x] Có localization tiếng Việt/Anh và widget test baseline.
- [x] Có Java `21`, Spring Boot `4.1.0`, Spring Modulith `2.1.0` và Gradle
  Wrapper `9.6.1`.
- [x] Có PostgreSQL `18`, Flyway migration, Docker Compose local và
  Testcontainers.
- [x] Có Spring Modulith verification test cho module boundary.
- [x] Có CI cho contract, backend, Flutter analyze/test, Android APK và Compose.
- [x] Đã xóa Dependabot version-update configuration để dừng bot tạo PR; không
  thay đổi Dependabot Alerts.
- [ ] Thiết lập policy review dependency thủ công định kỳ và cách xử lý security
  alert thay cho bot.
- [ ] Thiết lập secret scanning/dependency verification phù hợp trước release.

### Giai đoạn 3 — Vertical slice learning đầu tiên

Luồng: language/course catalog → lesson → multiple-choice exercise → attempt →
immediate feedback → course progress.

- [x] Backend cung cấp catalog, lesson delivery, attempt và progress API.
- [x] Attempt append-only và deduplicate bằng `Idempotency-Key` cùng
  `clientAttemptId`.
- [x] Progress chỉ hoàn thành exercise sau ít nhất một attempt đúng.
- [x] PostgreSQL migration có seed content phục vụ local journey.
- [x] Backend integration tests chạy API với PostgreSQL Testcontainers.
- [x] Android Flutter client gọi API qua Repository/Service và hiển thị flow học.
- [x] Có widget test cho happy path của flow học và validation khi chưa chọn đáp
  án.
- [x] Đã chạy `flutter analyze`, `flutter test`, Android APK build, backend
  `test bootJar`, contract lint và Compose validation.
- [ ] Tạo automated end-to-end test chạy Android emulator/client thật với backend
  và PostgreSQL local.
- [ ] Kiểm tra thủ công trên ít nhất một Android device/emulator mục tiêu và ghi
  nhận evidence.

Giai đoạn này chỉ được coi hoàn toàn đóng khi hai hạng mục end-to-end còn lại
được hoàn thành.

## 6. Backend completion track

Không bắt đầu Android frontend mới ở Mục 7 cho đến khi backend P0 tương ứng đã
vượt quality gate tại Mục 4.2. Thứ tự dưới đây ưu tiên dependency, không yêu cầu
triển khai mọi năng lực P2 trước bản Android đầu tiên.

### Giai đoạn 4 — Khóa phạm vi P0 và contract nền tảng

- [x] Chốt các quyết định P0 còn mở ở Giai đoạn 0.
- [x] Lập capability map P0/P1/P2 từ [Nghiep_Vu.md](Nghiep_Vu.md).
- [x] Xác định ownership cho identity-profile, curriculum-content,
  learning-session/assessment, mastery và review-scheduler.
- [x] Chuẩn hóa API error, pagination, idempotency và correlation/trace ID.
- [x] Định nghĩa privacy inventory, retention và deletion/export workflow.
- [x] Lập threat model cho backend và Android.
- [x] Chốt môi trường development/test/staging/production và promotion rule.

Đầu ra: decision record/ADR khi cần, contract cập nhật, acceptance criteria và
backlog có dependency.

### Giai đoạn 5 — Identity, profile và onboarding backend (P0)

- [x] Tích hợp external OIDC/OAuth2 trung lập provider cho production; giữ local
  guest issuer chỉ cho development. Việc chạy E2E với provider test/staging còn
  chờ issuer và tenant thực tế.
- [x] Mô hình subject mapping, learner profile, locale, source/target language,
  learning goal và preference.
- [x] Thiết kế guest lifecycle, account creation và idempotent guest-account
  merge.
- [x] Thiết kế role/permission cho learner, content staff, support và admin.
- [x] Thực thi consent/age gate và audit cho thay đổi nhạy cảm.
- [x] Thêm API profile/onboarding và authorization tests.
- [x] Thêm workflow export/delete account theo privacy decision.
- [x] Chạy security tests cho issuer, audience, expired token, scope/role và
  object-level authorization.

Gate: backend identity chạy được với provider test/staging; không dùng local
signing key ở production; integration/security tests pass.

Trạng thái gate: implementation và test tự động local đã đạt; gate chưa đóng vì
chưa có external provider test/staging để xác thực discovery/JWKS và token thật.

### Giai đoạn 6 — Curriculum, content và publishing backend (P0)

- [x] Mở rộng model language → course → unit → lesson → exercise, có locale và
  content version.
- [x] Bổ sung exercise type P0 sau multiple choice; mỗi loại có scoring contract
  rõ.
- [x] Tách authoring model khỏi learner delivery model cho mọi exercise.
- [x] Thiết kế lifecycle draft → review → approved → scheduled/published →
  retired.
- [x] Bổ sung effective date, compatibility và rollback cho content release.
- [x] Tạo admin/content APIs tối thiểu; chưa xây admin frontend ở giai đoạn này.
- [x] Thêm validation chống reference hỏng, answer leakage và publish content
  không hợp lệ.
- [x] Xác định media metadata và object-storage boundary; chỉ thêm storage khi
  bắt đầu dùng media thật.
- [x] Thêm integration tests cho version/publish/retire và learner delivery.

Gate: backend có thể phát hành một course P0 có version, audit và rollback; app
chỉ nhận content đã publish phù hợp.

Trạng thái gate: đạt bằng migration PostgreSQL, admin/learner API và integration
test Testcontainers. Giai đoạn 6 được thực hiện theo ưu tiên trực tiếp của
developer trong khi external OIDC staging gate của Giai đoạn 5 vẫn còn mở.

### Giai đoạn 7 — Learning, mastery, review và offline sync backend (P0)

- [x] Tách rõ learning session, assessment attempt, mastery evidence và review
  schedule.
- [x] Mở rộng scoring/feedback nhưng giữ attempt append-only.
- [x] Định nghĩa lesson/course completion và progress recalculation rule.
- [x] Xây mastery model có version và giải thích được evidence.
- [x] Xây review queue/spaced-repetition scheduler với clock-controllable tests.
- [x] Thiết kế offline write protocol: client mutation ID, idempotency, content
  version, sync cursor và conflict policy.
- [x] Xây pull/push sync API có pagination, tombstone và retry semantics.
- [x] Bảo đảm reconnect không tạo attempt trùng hoặc làm mất tiến độ.
- [x] Thêm concurrency, replay, conflict và recovery integration tests.

Gate: một learner có thể học offline, reconnect, đồng bộ attempt/progress và
nhận review queue nhất quán qua API test.

Trạng thái gate: đạt bằng migration PostgreSQL V4, contract OpenAPI 0.4.0,
module learning/mastery/review/sync và integration test Testcontainers bao phủ
replay, conflict, concurrent retry, recovery, pagination và clock-controlled
review. External OIDC staging gate của Giai đoạn 5 vẫn là dependency release
còn mở, không phải dependency logic của gate này.

### Giai đoạn 8 — Backend vận hành và năng lực sau P0

P0 trước Android release:

- [x] Structured logging, metrics, traces và correlation ID không chứa token/PII.
- [x] Health/readiness, timeout, retry budget và graceful shutdown.
- [x] Database backup/restore drill, migration rollback/forward-fix runbook.
- [x] Rate limit/quota cho endpoint tốn tài nguyên.
- [x] Audit trail cho admin/content/security actions.
- [x] Load test journey P0 và xác lập SLO/error budget ban đầu.
- [x] Kiểm tra OWASP ASVS phù hợp cho API/backend.

Trạng thái gate P0: đạt bằng ECS structured console log, Prometheus/OpenTelemetry,
probe và graceful shutdown; rate limit/audit PostgreSQL có integration test; backup
và restore V1→V5 được diễn tập bằng PostgreSQL 18; P0 journey local đạt 361 request,
0 lỗi, read p95 40,42 ms và mutation p95 244,19 ms. ASVS 5.0 self-review không phát
hiện P0 source-code finding mới; external OIDC, TLS/KMS, DAST và supply-chain vẫn là
release/environment gate của Giai đoạn 9. Limiter P0 chỉ bảo đảm quota cho một
instance và phải chuyển lên gateway/distributed limiter trước khi scale ngang.

P1 sau khi core P0 ổn định:

- [ ] Pronunciation/listening/writing/conversation contract và provider ports.
- [ ] AI/speech gateway có quota, safety, evaluation và provider fallback.
- [ ] Assessment/placement/certification backend.
- [ ] Goal, streak, achievement, notification preference backend.
- [ ] Subscription, entitlement, purchase verification và refund lifecycle.
- [ ] Support, moderation, organization/class và experimentation backend.

P2 chỉ khi có requirement và số liệu:

- [ ] Broker/event streaming ngoài tiến trình.
- [ ] Redis/cache phân tán.
- [ ] Tách deployable service, Kubernetes hoặc data/ML platform riêng.

### Giai đoạn 9 — Backend release gate

- [x] Toàn bộ contract P0 lint và compatibility review pass.
- [x] Toàn bộ unit/integration/security/module regression tests pass.
- [x] Test trên PostgreSQL version mục tiêu và migration từ baseline gần nhất.
- [ ] Staging dùng external identity và production-like configuration.
- [x] Backup/restore, rollback/forward-fix và incident runbook được diễn tập.
- [ ] Không còn P0 security/privacy finding chưa có chấp nhận rủi ro.
- [x] API documentation và Android integration fixtures được đóng băng cho đợt
  tích hợp.

Trạng thái gate: contract 0.4.0 đã lint, oasdiff và khóa SHA-256 cùng fixture
bao phủ 21 mobile operation; 24 backend test, Modulith, bootJar và PostgreSQL 18
Flyway V1→V5 đều pass. Backup/restore/runbook dùng lại evidence diễn tập của Giai
đoạn 8. Fixture consumer test đã pass bằng Flutter 3.44.3; lỗi CI mobile do
format fixture đã được sửa và format/analyze/test local đều pass. External OIDC
staging, TLS/KMS và hai high ASVS finding chưa có risk
acceptance tiếp tục chặn hoàn thành Giai đoạn 9.

## 7. Android frontend track

Chỉ bắt đầu từng nhóm tích hợp sau khi backend contract tương ứng đạt Giai đoạn
9 hoặc một backend release gate nhỏ đã được developer phê duyệt.

### Giai đoạn 10 — Android application foundation (P0)

- [x] Chốt navigation, design tokens, typography, component states và responsive
  behavior.
- [x] Chọn local database/secure storage theo requirement; ghi ADR nếu tạo
  dependency nền tảng mới.
- [x] Xây auth/session lifecycle, token refresh và logout an toàn.
- [x] Xây network layer có timeout, retry policy, error mapping và trace header.
- [x] Xây offline repository/sync coordinator theo contract backend.
- [x] Thiết lập environment/flavor cho local, staging và production.
- [x] Thiết lập analytics abstraction, privacy consent và crash reporting.
- [x] Thiết lập accessibility baseline và localization QA.
- [x] Bổ sung golden/widget/integration test strategy phù hợp.

Trạng thái gate: đạt bằng ADR-006, route và Material 3 design system dùng chung,
secure token/session lifecycle, HTTP policy có correlation/retry/error mapping,
SQLite outbox cùng cursor sync, ba Android flavor và cleartext chỉ ở local.
Format, analyzer, 17 Flutter test và APK `localDebug` đã pass bằng Flutter
3.44.3. External OIDC staging, production telemetry sink, release signing và
device-matrix E2E vẫn là release/environment gate; không chặn bắt đầu Giai đoạn
11.

### Giai đoạn 11 — Android core learner journey (P0)

- [ ] Onboarding, guest/account flow và learner profile.
- [ ] Language/course selection và learning path.
- [ ] Download/cache course, lesson và media cần thiết.
- [ ] Lesson/exercise/attempt/feedback với đầy đủ trạng thái lỗi.
- [ ] Progress, mastery và review queue.
- [ ] Offline learning, pending mutations, reconnect và conflict messaging.
- [ ] Daily goal và notification preference tối thiểu nếu thuộc P0 đã chốt.
- [ ] Privacy controls: consent, export/delete request và log redaction.
- [ ] Accessibility: screen reader semantics, focus order, contrast, text scale
  và touch target.
- [ ] End-to-end regression trên emulator và thiết bị Android đại diện.

### Giai đoạn 12 — Android advanced learning (P1)

- [ ] Listening và media playback/download.
- [ ] Pronunciation recording, permission, consent và retention UX.
- [ ] Writing feedback và conversation experience.
- [ ] Placement/assessment và certificate display.
- [ ] Personalization, review recommendation và learning insight.
- [ ] Streak, achievement/challenge và notification.
- [ ] Subscription/paywall/entitlement khi commerce backend đã sẵn sàng.
- [ ] Support/report-content flow.

### Giai đoạn 13 — Android release readiness

- [ ] Application ID, signing, Play App Signing và key custody được chốt.
- [ ] Versioning, release notes và staged rollout strategy.
- [ ] Release build minify/resource shrinking được kiểm tra.
- [ ] Android App Bundle build và upload internal testing thành công.
- [ ] Kiểm tra device/API-level matrix, rotation, background/foreground,
  low-storage và network changes.
- [ ] Performance: startup, jank, memory, battery, network và APK/AAB size.
- [ ] OWASP MASVS/MASTG review cho storage, auth, network, platform, code và
  privacy.
- [ ] Data safety form, privacy policy, permission disclosure và store listing.
- [ ] Crash-free/session SLO, alert và rollback/stop-rollout procedure.
- [ ] Product acceptance và regression journey P0 pass trên staging.

## 8. Thứ tự sprint đề xuất gần nhất

Đây là queue thực thi ngay sau tài liệu này:

1. **Sprint A — đóng Foundation/first-slice evidence**
   - [ ] Tạo Android ↔ backend ↔ PostgreSQL end-to-end test.
   - [ ] Chạy smoke test trên emulator/device và lưu kết quả.
   - [ ] Thêm contract breaking-change check.
   - [ ] Hoàn thiện dependency/security alert review policy.
2. **Sprint B — khóa quyết định P0**
   - [x] Chốt thị trường/ngôn ngữ/độ tuổi đầu tiên.
   - [x] Chốt guest-account merge, consent và privacy retention.
   - [x] Chốt P0 capability, SLO và acceptance criteria.
3. **Sprint C — identity/profile backend**
   - [ ] Thực hiện Giai đoạn 5 và đạt backend gate.
4. **Sprint D — curriculum/content backend**
   - [x] Thực hiện Giai đoạn 6 và đạt backend gate.
5. **Sprint E — learning/mastery/review/offline backend**
   - [x] Thực hiện Giai đoạn 7 và đạt backend gate.
6. **Sprint F — backend hardening**
   - [ ] Hoàn thành P0 của Giai đoạn 8 và Giai đoạn 9.
7. **Sprint G trở đi — Android integration**
   - [ ] Thực hiện Giai đoạn 10, 11 rồi 13; P1 ở Giai đoạn 12 chỉ chen vào khi
     đã được developer ưu tiên.

## 9. Quy tắc cập nhật kế hoạch

1. Trước khi code, liên kết yêu cầu với một checklist và xác nhận dependency.
2. Nếu yêu cầu chưa có trong kế hoạch, thêm đúng giai đoạn trước khi triển khai.
3. Sau khi làm, ghi validation ngay trong change log hoặc evidence liên quan.
4. Chỉ chuyển `[ ]` thành `[x]` khi đạt Definition of Done tương ứng.
5. Khi một quyết định thay đổi, cập nhật ADR/source-of-truth trước, rồi cập nhật
   kế hoạch; không chỉnh checklist để che xung đột.
6. Mỗi lần chuẩn bị sprint, review lại toàn bộ hạng mục mở của giai đoạn hiện
   tại và các dependency trực tiếp; không cần review lại mọi hạng mục P2.
7. Native iOS chỉ được thêm vào roadmap khi developer chủ động đổi ưu tiên.

## 10. Nguồn tham khảo

Các nguồn sau định hướng quality gate và kiến trúc. Thứ tự phase cụ thể là quyết
định của EsquiloSpeak dựa trên dependency trong repo.

- [Flutter — Guide to app architecture](https://docs.flutter.dev/app-architecture/guide)
- [Flutter — Offline-first support](https://docs.flutter.dev/app-architecture/design-patterns/offline-first)
- [Flutter — Testing overview](https://docs.flutter.dev/testing/overview)
- [Android Developers — Guide to app architecture](https://developer.android.com/topic/architecture)
- [Android Developers — Test apps on Android](https://developer.android.com/training/testing)
- [Android Developers — Prepare and roll out a release](https://developer.android.com/studio/publish/preparing)
- [Spring Modulith — Reference](https://docs.spring.io/spring-modulith/reference/)
- [Spring Modulith — Verify application modules](https://docs.spring.io/spring-modulith/reference/verification.html)
- [Spring Security — OAuth 2.0 Resource Server JWT](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html)
- [OpenAPI Specification](https://spec.openapis.org/oas/latest.html)
- [JSON Schema Specification](https://json-schema.org/specification)
- [PostgreSQL documentation](https://www.postgresql.org/docs/current/)
- [Flyway documentation](https://documentation.red-gate.com/flyway)
- [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/)
- [OWASP MASVS](https://mas.owasp.org/MASVS/)
- [OWASP MASTG](https://mas.owasp.org/MASTG/)
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)
- [NIST Secure Software Development Framework](https://csrc.nist.gov/pubs/sp/800/218/final)
