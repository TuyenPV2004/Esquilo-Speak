# Kế hoạch hoàn thiện sản phẩm EsquiloSpeak — Phần 2

## 1. Mục đích và trạng thái

Tài liệu này là kế hoạch thực thi sau khi MVP Giai đoạn 12 đã được xác nhận,
nhưng trước khi mở khóa **Giai đoạn 13 — Android release readiness** trong
[Kế hoạch Phần 1](Ke_Hoach_1.md#giai-đoạn-13--android-release-readiness).

Mục tiêu của Phần 2 là biến MVP chứng minh kỹ thuật thành một learning product
beta có nội dung đủ sâu, có vòng lặp học hằng ngày, có công cụ vận hành content
và có bằng chứng người dùng thực sự học được. Giai đoạn 13 chỉ bắt đầu sau khi
Product Completion Gate ở cuối tài liệu này đạt đầy đủ.

Trạng thái baseline:

- [x] Android MVP chạy được với backend và PostgreSQL local.
- [x] Hành trình học P0 và advanced learning P1 đã có bằng chứng E2E.
- [x] Developer đã test và xác nhận MVP đủ để thể hiện hướng sản phẩm.
- [x] Quyết định giữ nguyên nhưng tạm khóa Giai đoạn 13 release readiness.
- [ ] Product Completion Gate của Phần 2 đã đạt.
- [ ] Giai đoạn 13 được developer xác nhận mở khóa.

## 2. Định hướng sản phẩm mặc định

Trừ khi có quyết định mới được ghi vào ADR/product decision record, kế hoạch sử
dụng các mặc định sau:

- Thị trường đầu tiên: người Việt trưởng thành học tiếng Anh.
- Track đầu tiên: English A1 giao tiếp nền tảng.
- Trải nghiệm chính: learning path có cấu trúc, lesson ngắn và daily session.
- Practice mode: tái sử dụng cùng learning item theo hướng flashcard, adaptive
  practice, test và matching; không xây một bản sao Quizlet.
- Curriculum được biên soạn và review có kiểm soát; chưa mở public UGC.
- CEFR là khung tham chiếu outcome cho track tiếng Anh, không hardcode cho mọi
  ngôn ngữ.
- Content-as-code và preview được ưu tiên trước khi đầu tư full CMS.
- AI chỉ hỗ trợ tạo draft/feedback có boundary; canonical content phải qua human
  review.
- Daily goal và streak là hai khái niệm riêng; không tối ưu cho XP grinding.

Tài liệu nguồn:

- [Phạm vi sản phẩm](../shared/Project.md)
- [Nghiệp vụ hoàn chỉnh](../shared/Nghiep_Vu.md)
- [Kiến trúc hệ thống](../architecture/Tech_Stack_And_Architecture.md)
- [Kế hoạch nền tảng và release gate](Ke_Hoach_1.md)

## 3. Phạm vi beta mục tiêu

Beta đầu tiên được xem là đủ sâu khi có tối thiểu:

- 1 course `vi → en` ở mức A1.
- 4 unit, khoảng 20 lesson và checkpoint cuối mỗi unit.
- Mỗi lesson 5–8 phút, khoảng 8–12 exercise.
- Mỗi lesson giới thiệu có kiểm soát khoảng 5–7 từ/cấu trúc mới.
- Ít nhất 8 kiểu hoạt động học ổn định.
- Daily session kết hợp lesson mới, review đến hạn và luyện điểm yếu.
- Flashcard/adaptive practice/test/matching dùng lại content canonical.
- Writing, pronunciation và conversation được tích hợp vào learning path.
- Content có EN/VI, outcome, skill, concept, answer policy, explanation, media
  provenance và accessibility alternative khi cần.
- Online/offline/reconnect giữ đúng attempt, progress và mastery.

Các con số trên là baseline để lập kế hoạch. Mọi thay đổi lớn phải được ghi lý
do, tác động và acceptance criteria trước khi sửa phạm vi.

## 4. Definition of Done dùng chung

Một hạng mục chỉ được đánh dấu hoàn thành khi:

- [ ] Contract/schema và migration tương thích ngược hoặc có migration policy.
- [ ] Authoring payload không bị lộ đáp án trong learner delivery.
- [ ] Backend unit/integration test và contract check tương ứng pass.
- [ ] Flutter unit/widget/integration test tương ứng pass.
- [ ] Android local/closed-testing journey pass trên thiết bị mục tiêu.
- [ ] Offline, reconnect, retry và idempotency đã được xác minh nếu có mutation.
- [ ] EN/VI, 200% text, semantics và tap target đã được kiểm tra.
- [ ] Privacy, permission, retention và safety boundary đã được kiểm tra.
- [ ] Tài liệu API, hướng dẫn test, roadmap và change log được cập nhật.
- [ ] Có evidence hoặc số liệu đủ để reviewer xác nhận checkbox.

## Giai đoạn 1 — Proficiency framework và curriculum A1

### Mục tiêu

Loại bỏ giả định một framework/level duy nhất khỏi domain, sau đó chuyển định
hướng “học tiếng Anh A1” thành curriculum có outcome, progression và quy tắc
nội dung đủ rõ để author có thể xây nhiều lesson nhất quán. CEFR/A1 là dữ liệu
của course tiếng Anh đầu tiên, không phải enum hoặc nhánh logic toàn hệ thống.

### Checklist

- [x] Định nghĩa proficiency framework có code, version, phạm vi áp dụng và
  nguồn tham chiếu; không enum CEFR trong application logic.
- [x] Định nghĩa proficiency level có code, thứ tự, tên/descriptor đa locale và
  liên kết tới đúng framework version.
- [x] Course version tham chiếu framework cùng target level bằng dữ liệu và
  database foreign key.
- [x] Placement definition, attempt và completion record giữ nguyên framework
  version/level code của evidence.
- [x] Contract và Flutter consumer đọc proficiency reference động, không dùng
  `const: A1` hoặc chuỗi A1 trong logic; OpenAPI lint, Flutter analyzer và toàn
  bộ Flutter test đã pass ngày 2026-07-31.
- [x] Seed CEFR/A1 cho course `vi → en` hiện tại nhưng cho phép bổ sung A2, B1
  hoặc framework khác mà không sửa application code.
- [x] Chọn source/target language và active course từ learner state thay vì
  mặc định cố định `vi → en` trong learner journey.
- [x] Tách `uiLocale` khỏi source/target language; app cho phép đổi ngôn ngữ
  giao diện độc lập và giữ BCP 47 language tag trong profile/cache.
- [x] Nội dung placement, feedback, concept và achievement dùng localized
  metadata hoặc message code từ contract, không hiển thị raw domain ID/code
  trong luồng production thông thường.
- [x] Chốt learner persona, nhu cầu giao tiếp và phạm vi loại trừ của course A1.
- [x] Chốt course outcome và can-do outcome cho từng unit theo CEFR phù hợp.
- [x] Thiết kế 4 unit, khoảng 20 lesson và checkpoint của từng unit.
- [x] Gắn prerequisite, skill, concept và evidence mong đợi cho từng lesson.
- [x] Lập vocabulary/phrase/grammar inventory có thứ tự giới thiệu và tái xuất hiện.
- [x] Định nghĩa lesson template: warm-up, introduction, guided practice,
  independent practice, mistake review và summary.
- [x] Định nghĩa difficulty policy, hint, retry, partial credit và answer policy.
- [x] Viết content style guide EN/VI, tone, cultural review và safety rule.
- [x] Chốt media guideline: giọng đọc, tốc độ, license, transcript và text alternative.
- [x] Chốt acceptance rubric cho language, pedagogy, media và accessibility review.

### Gate

- [x] Curriculum owner/developer phê duyệt course map và Unit 1 specification.
- [x] Mỗi lesson Unit 1 có outcome, concept, skill, vocabulary và assessment evidence.
- [x] Không còn quyết định pedagogy blocking việc mở rộng schema/exercise engine.

Trạng thái gate: curriculum specification, Unit 1 specification và content
standards đã được tạo dưới
[`content/courses/course-en-for-vi/`](../../content/courses/course-en-for-vi/).
Các artifact khóa persona, 4 unit/20 lesson, progression, evidence, lesson flow,
scoring/feedback, media, cultural safety và acceptance rubric dựa trên CEFR 2020.
Developer đã phê duyệt mở Giai đoạn 2 bằng yêu cầu thực hiện ngày 2026-08-01;
đây đồng thời là acceptance của course map và Unit 1 specification cho dependency
authoring. Mọi điều chỉnh pedagogy sau review tiếp tục tạo version artifact mới,
không sửa ngầm contract đã publish.

## Giai đoạn 2 — Content contract và authoring pipeline

### Mục tiêu

Cho phép tạo, validate, preview, review và publish content mà không sửa Dart hoặc
Java cho từng lesson.

### Checklist

- [x] Mở rộng lesson/content schema theo discriminated exercise types.
- [x] Tách rõ learning item, exercise presentation, answer policy và feedback rule.
- [x] Giữ scoring answer/explanation nhạy cảm ngoài learner delivery.
- [x] Bổ sung metadata outcome, prerequisite, difficulty, hint, media và accessibility.
- [x] Tạo template JSON/YAML cho course, unit, lesson, exercise và media manifest.
- [x] Tạo validator cho schema, reference, duplicate ID, locale và answer integrity.
- [x] Tạo semantic validator cho concept coverage, content repetition và media metadata.
- [x] Tạo lệnh import/update draft vào lifecycle backend hiện có.
- [x] Tạo preview dùng cùng learner renderer hoặc một preview adapter tối thiểu.
- [x] Bổ sung review checklist và audit evidence trước publish.
- [x] Kiểm tra publish, schedule, rollback, retire và compatibility với progress cũ.
- [x] Ghi rõ tiêu chí khi nào mới cần xây admin web/CMS.

### Gate

- [x] Author tạo và publish được một lesson mới mà không sửa application code.
- [x] Invalid content bị từ chối với lỗi có thể hành động được.
- [x] Published version bất biến; sửa nội dung tạo version mới và rollback được.

Trạng thái gate: đạt bằng content package JSON nhiều file, Draft 2020-12 schema,
validator structural/semantic, learner-safe HTML preview và CLI import/lifecycle
không thêm dependency runtime. Package `authoring-demo` compile thành admin DTO và
được integration test phát hành qua backend mà không sửa application code theo
từng lesson; learner payload không chứa answer/explanation. Review thiếu một trong
bảy evidence bắt buộc bị trả `422`; checklist hợp lệ được lưu trong audit trail.
Lifecycle publish/schedule/retire/rollback, published immutability và compatibility
với attempt/progress version cũ tiếp tục được full backend regression bảo vệ.

## Giai đoạn 3 — Exercise engine V2

### Mục tiêu

Biến lesson renderer hiện tại thành engine mở rộng được, dùng chung contract,
attempt, feedback, mastery và offline behavior.

### Checklist nền tảng

- [x] Thiết kế registry/renderer theo exercise type, không tạo một màn hình lớn
  chứa mọi nhánh.
- [x] Chuẩn hóa response payload, validation, answer normalization và scoring result.
- [x] Chuẩn hóa hint usage, retry, response time, confidence và input modality evidence.
- [x] Định nghĩa accessibility behavior và silent/audio mode cho từng type.
- [x] Định nghĩa offline serialization, outbox mutation và reconnect reconciliation.
- [x] Thêm test contract fixture cho mọi exercise type.

### Checklist kiểu hoạt động

- [ ] Multiple choice được harden cho text/image/audio option.
- [x] True/false được harden cho feedback và accessibility.
- [x] Flashcard/reveal với `Know` và `Still learning`.
- [x] Matching term–definition hoặc phrase–meaning.
- [x] Listen and select.
- [x] Word/sentence ordering.
- [x] Fill in the blank với answer normalization.
- [x] Dictation ngắn với transcript/diacritic policy.
- [x] Reading/listening comprehension dùng chung primitive ổn định.
- [x] Writing, pronunciation và conversation P1 được tích hợp như hoạt động lesson.

### Gate

- [x] Tối thiểu 8 kiểu hoạt động P0 chạy được trong cùng learner journey.
- [x] Mỗi type có unit/widget/contract test và error state.
- [x] Attempt, mastery và review evidence không phụ thuộc UI type cụ thể.

## Giai đoạn 4 — Unit 1 vertical slice hoàn chỉnh

### Mục tiêu

Chứng minh content pipeline và exercise engine bằng một unit thực sự có thể học,
không chỉ fixture kỹ thuật.

### Nội dung mặc định

1. Chào hỏi.
2. Giới thiệu tên.
3. Hỏi thăm và phản hồi đơn giản.
4. Số và tuổi.
5. Checkpoint Unit 1.

### Checklist

- [x] Biên soạn và review đủ 5 lesson theo template đã duyệt.
- [x] Thu âm/tạo media có transcript, provenance và accessibility alternative.
- [x] Mỗi lesson dùng phối hợp nhận biết, recall, listening và production.
- [x] Lesson cuối unit có checkpoint nhiều skill, không chỉ vocabulary recognition.
- [x] Learning path hiển thị unit, lesson, trạng thái khóa/mở và tiến độ.
- [x] Resume lesson hoạt động đúng sau khi đóng app.
- [x] Mistake review xuất hiện trước session summary.
- [x] Hoàn thành Unit 1 cập nhật progress, mastery và review schedule đúng.
- [x] Unit 1 tải được để học offline và đồng bộ lại không ghi trùng attempt.
- [x] Chạy content QA, accessibility QA và E2E Android cho toàn unit.

### Gate

- [ ] Một learner mới đi từ onboarding đến hoàn thành Unit 1 không cần thao tác kỹ thuật.
- [ ] Không có lỗi P0 làm mất progress, attempt hoặc chặn hành trình.
- [ ] Content owner ký xác nhận chất lượng ngôn ngữ và pedagogy Unit 1.

Trạng thái ngày 2026-08-01: checklist kỹ thuật của vertical slice đã hoàn tất. Media
gồm 10 tệp WAV có transcript, silent alternative, checksum và provenance; learning
path/download được kiểm chứng offline và idempotent; backend xử lý đủ 45 attempt của
5 lesson; Android instrumentation pass trên emulator API 37. Ba gate phía trên vẫn
mở vì chưa có một lần chạy liên thông onboarding → Unit 1 với backend thật, chưa đủ
bằng chứng để loại trừ mọi lỗi P0 trong hành trình đó và chưa có content-owner sign-off.

## Giai đoạn 5 — Daily learning loop và Home V2

### Mục tiêu

Tạo lý do rõ ràng để learner quay lại mỗi ngày và luôn biết bước tiếp theo.

### Checklist

- [x] Xây daily-session composer từ lesson tiếp theo, review đến hạn và điểm yếu.
- [x] Home hiển thị một primary CTA cùng lý do đề xuất.
- [x] Có quick practice 3–5 phút khi learner không đủ thời gian học lesson mới.
- [x] Kết thúc phiên hiển thị outcome đạt được, lỗi cần ôn và bước tiếp theo.
- [x] Tách streak khỏi daily goal về model và UI.
- [x] Goal hỗ trợ phút, lesson hoặc review target theo policy.
- [x] Streak chỉ tăng từ hoạt động học có evidence hợp lệ.
- [x] Reminder tôn trọng consent, timezone, quiet hours và denial state.
- [x] Backlog review được giới hạn hợp lý nhưng vẫn minh bạch.
- [x] Daily session hoạt động offline trong phạm vi content đã tải.
- [x] Thêm event/metric tối thiểu cho start, completion, abandon và recommendation source.

### Gate

- [x] Learner mở app và bắt đầu daily session trong tối đa hai thao tác.
- [x] Daily session hoàn thành được ngay cả khi không có lesson mới.
- [x] Không thể spam attempt/XP để tạo streak hoặc thành tích sai.

Bằng chứng đóng gate: `DailySessionComposer` có test deterministic cho thứ tự ưu
tiên, review cap, offline readiness và fallback sau khi hết lesson; Home V2 chỉ
có một filled CTA để bắt đầu; quick practice tái sử dụng lesson/exercise canonical
và ghi `practiceMode`; integration test engagement trên PostgreSQL xác nhận
evidence ownership, unique rewarded evidence, lifecycle event 0 XP và quiet-hours
policy. Flutter analyzer cùng full mobile suite và backend regression là quality
gate bắt buộc của thay đổi này.

## Giai đoạn 6 — Practice modes dùng lại content

### Mục tiêu

Cho learner nhiều cách luyện cùng một content canonical mà không nhân bản dữ
liệu hoặc tách rời mastery.

### Checklist

- [x] Flashcards: lật thẻ, shuffle, audio và phân loại biết/chưa biết.
- [x] Adaptive Learn: tăng dần từ recognition sang recall theo evidence.
- [x] Practice Test: cấu hình số câu/type, chấm điểm và summary.
- [x] Match: ghép cặp theo lượt ngắn, không dùng tốc độ làm mastery duy nhất.
- [x] Mistakes practice: luyện lại lỗi gần đây.
- [x] Weak concepts practice: chọn concept có mastery thấp/sắp quên.
- [x] Cho phép chọn phạm vi unit/lesson/concept khi luyện chủ động.
- [x] Mọi mode ghi attempt/evidence nhất quán và không làm sai progress course.
- [x] Mode có giới hạn và fallback phù hợp khi offline.
- [x] Accessibility không phụ thuộc gesture hoặc tốc độ.

### Gate

- [x] Một learning item được dùng trong ít nhất ba mode mà không copy canonical data.
- [x] Personalized selection có explanation và test deterministic.
- [x] Practice mode không tạo đường tắt hoàn thành curriculum ngoài policy.

### Bằng chứng hoàn thành ngày 2026-08-02

Practice selector giữ trực tiếp tham chiếu `Lesson`/`Exercise` canonical và test dùng cùng
object/version qua Flashcards, Practice Test và Mistakes. Selector deterministic theo seed,
scope, mastery/review/lỗi gần nhất và luôn trả explanation/fallback; adaptive test chứng minh
mastery thấp ưu tiên recognition, mastery cao ưu tiên recall. SQLite schema V3 lưu kết quả mới
nhất để luyện lỗi khi offline; các mode chỉ tải lesson đã cache khi mạng không khả dụng.

Attempt evidence dùng enum `practiceMode` đồng nhất trên OpenAPI/Java/Dart. Integration test
PostgreSQL xác nhận practice attempt đúng vẫn tạo mastery evidence nhưng
`completedExerciseCount = 0`, lesson `not_started` và không có completion shortcut. Full backend
regression cùng `bootJar`, OpenAPI lint/P0 freeze, Flutter analyzer và 61/61 mobile test đều pass;
widget test khóa lật thẻ/audio/control nút ở text 200%. Debug APK build thành công; Android device
test không chạy trong lượt này vì `flutter devices` không phát hiện target Android.

## Giai đoạn 7 — Hoàn thiện course A1

### Mục tiêu

Mở rộng từ Unit 1 đã được kiểm chứng thành course A1 đủ dùng cho closed beta.

### Checklist

- [ ] Hoàn thiện Unit 2 — Thông tin cá nhân.
- [ ] Hoàn thiện Unit 3 — Cuộc sống hằng ngày.
- [ ] Hoàn thiện Unit 4 — Giao tiếp trong tình huống.
- [ ] Mỗi unit có guidebook/tóm tắt kiến thức và checkpoint.
- [ ] Vocabulary/grammar được interleave và tái xuất hiện theo curriculum map.
- [ ] Listening, speaking, reading và writing có tỷ lệ evidence phù hợp A1.
- [ ] Placement đề xuất đúng điểm bắt đầu nhưng cho learner chọn mức thấp hơn.
- [ ] Completion assessment lấy mẫu nhiều skill.
- [ ] Toàn bộ content qua language, pedagogy, cultural, media và accessibility review.
- [ ] Có version migration policy cho learner đang học khi course được sửa.
- [ ] Full-course offline package có dung lượng, version và cache policy rõ ràng.

### Gate

- [ ] Có tối thiểu 4 unit/20 lesson đã publish và learner-safe.
- [ ] Learner hoàn thành được toàn course trên Android closed-testing.
- [ ] A1 completion vẫn được mô tả đúng là non-accredited nếu chưa có công nhận ngoài.

## Giai đoạn 8 — Product quality, analytics và personalization

### Mục tiêu

Đo chất lượng học và cải thiện recommendation dựa trên evidence, không tối ưu
đơn thuần cho thời gian dùng app hoặc XP.

### Checklist

- [ ] Chuẩn hóa learning-session, lesson, review và practice funnel.
- [ ] Đo first-lesson completion, Unit 1 completion, D1/D7 retention và review completion.
- [ ] Đo drop-off theo lesson/exercise type mà không thu dữ liệu không cần thiết.
- [ ] Đo correctness, retry, hint usage, response time hợp lý và content report rate.
- [ ] Xây dashboard nội bộ tối thiểu cho product/content quality.
- [ ] Tạo content-quality queue từ report, difficulty anomaly và feedback usefulness.
- [ ] Nâng recommendation từ heuristic sang rule/model versioned có explanation.
- [ ] Tạo offline evaluation dataset và rollback rule trước khi đổi scheduler/model.
- [ ] Thiết lập privacy retention và consent enforcement cho analytics.
- [ ] Định nghĩa experiment guardrail; không A/B test làm giảm learning outcome/safety.

### Gate

- [ ] Mọi north-star/supporting metric có định nghĩa và nguồn dữ liệu kiểm chứng được.
- [ ] Recommendation luôn có fallback deterministic và lý do hiển thị được.
- [ ] Content team truy vết được lesson/exercise gây drop-off hoặc report bất thường.

## Giai đoạn 9 — Closed beta và Product Completion Gate

### Mục tiêu

Xác nhận app đã hoàn thiện về sản phẩm đủ để bắt đầu release readiness, dựa trên
người dùng và evidence thay vì chỉ dựa trên số lượng tính năng.

### Closed-beta checklist

- [ ] Chốt test cohort, consent, feedback channel và support SLA nội bộ.
- [ ] Chạy beta trên nhiều Android API level và tối thiểu một số thiết bị thật.
- [ ] Thu phản hồi định tính về onboarding, path, lesson, daily loop và feedback.
- [ ] Đo first-lesson completion và Unit 1 completion.
- [ ] Đo D1/D7 retention sau thời gian quan sát hợp lý.
- [ ] Xử lý content report P0/P1 và đóng vòng phản hồi với tester.
- [ ] Không còn lỗi P0; lỗi P1 có owner, kế hoạch và quyết định release rõ.
- [ ] Backup/restore, privacy export/delete và support workflow được diễn tập lại.
- [ ] Full regression P0/P1, offline/reconnect và physical-device microphone pass.

### Product Completion Gate bắt buộc

- [ ] Course A1 có tối thiểu 4 unit/20 lesson đã publish và được review.
- [ ] Có ít nhất 8 exercise type ổn định và được tích hợp vào lesson.
- [ ] Daily session, review, practice modes và session summary hoạt động end-to-end.
- [ ] Authoring/validation/preview/publish không yêu cầu sửa application code mỗi lesson.
- [ ] Writing, pronunciation và conversation xuất hiện trong learning path phù hợp.
- [ ] Online/offline/reconnect không làm mất hoặc nhân đôi acknowledged attempt.
- [ ] Accessibility, privacy, safety và localization gate pass.
- [ ] Product metrics và closed-beta feedback cho thấy hướng sản phẩm được chấp nhận.
- [ ] Product owner/developer ký xác nhận app đủ hoàn thiện để chuẩn bị phát hành.
- [ ] Developer xác nhận bằng văn bản việc mở khóa Giai đoạn 13 trong Phần 1.

## 14. Thứ tự thực hiện và dependency

```text
Giai đoạn 1 — Proficiency framework/curriculum
        ↓
Giai đoạn 2 — Content contract/authoring ──┐
        ↓                        │
Giai đoạn 3 — Exercise engine V2          │
        ↓                        │
Giai đoạn 4 — Unit 1 vertical slice ◀─────┘
        ↓
Giai đoạn 5 — Daily learning loop
        ↓
Giai đoạn 6 — Practice modes
        ↓
Giai đoạn 7 — Full A1 course
        ↓
Giai đoạn 8 — Quality/analytics/personalization
        ↓
Giai đoạn 9 — Closed beta + Product Completion Gate
        ↓
Giai đoạn 13 — Android release readiness
```

Giai đoạn 2 và 3 có thể phát triển xen kẽ theo từng vertical slice, nhưng không
được xây toàn bộ engine trước khi có content Unit 1 dùng để kiểm chứng. Giai
đoạn 8 bắt đầu instrumentation tối thiểu từ Giai đoạn 4, sau đó hoàn thiện khi
course đã đủ sâu.

## 15. Metrics và ngưỡng quyết định ban đầu

- [ ] North star: weekly learner hoàn thành ít nhất một learning session có
  mastery hoặc completion evidence.
- [ ] Ít nhất 60% learner bắt đầu lesson đầu tiên hoàn thành lesson đó.
- [ ] Theo dõi Unit 1 completion và D1/D7 retention; chốt baseline sau closed beta.
- [ ] Zero confirmed loss của acknowledged attempt.
- [ ] Duplicate logical mutation thấp hơn 0,01% accepted attempts.
- [ ] Android crash-free session đạt tối thiểu 99,5% trước khi mở Giai đoạn 13.
- [ ] Mọi content report nghiêm trọng có triage owner và audit trail.

Các ngưỡng retention/content completion ngoài hai baseline đã khóa chỉ được chốt
sau khi có cohort đủ đại diện; không đặt vanity target khi chưa có dữ liệu.

## 16. Ngoài phạm vi cho đến khi có quyết định mới

- [ ] Không mở marketplace/public UGC trước khi có moderation, copyright và
  age/privacy policy.
- [ ] Không xây full CMS trước khi content-as-code được kiểm chứng là điểm nghẽn.
- [ ] Không xây leaderboard/social cạnh tranh trước khi có opt-in và guardrail.
- [ ] Không bật Google Play Billing production trước Giai đoạn 13.
- [ ] Không dùng AI-generated content làm canonical nếu chưa qua human review.
- [ ] Không tuyên bố chứng chỉ A1 được công nhận nếu chưa có issuer/accreditation.
- [ ] Không mở thêm language track trước khi course A1 đầu tiên đạt quality gate.

## 17. Quy tắc cập nhật kế hoạch

1. Chỉ đánh dấu `[x]` khi có artifact và evidence tương ứng.
2. Mỗi sprint liên kết hạng mục với một giai đoạn và acceptance gate ở trên.
3. Thay đổi curriculum/contract lớn phải cập nhật source of truth trước khi code.
4. Content, backend, mobile, test và tài liệu được giao theo vertical slice.
5. Hạng mục bị loại bỏ phải ghi rõ lý do, thay thế và tác động.
6. Không mở Giai đoạn 13 bằng cách hạ tiêu chí Product Completion Gate.
7. Khi Product Completion Gate đạt, cập nhật Phần 1, Phần 2 và change log trong
   cùng thay đổi.
