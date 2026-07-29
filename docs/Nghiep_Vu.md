# EsquiloSpeak — Mô tả nghiệp vụ hoàn chỉnh

> Trạng thái: **Mô hình nghiệp vụ mục tiêu; chưa phải cam kết phạm vi cho một release cụ thể**  
> Cập nhật lần cuối: **2026-07-16**  
> Phạm vi: **Nghiệp vụ của sản phẩm hoàn thiện dành cho người học, content team, support, commerce và tổ chức**  
> Không thuộc phạm vi: **Code, framework, database, API endpoint, deployment topology và cấu trúc source code**

## 1. Mục đích

Tài liệu trả lời câu hỏi: nếu EsquiloSpeak được hoàn thiện như một nền tảng học ngoại ngữ đầy đủ thì hệ thống phải hỗ trợ những nghiệp vụ nào, ai thực hiện, dữ liệu nghiệp vụ nào được tạo ra và các quy tắc quan trọng là gì.

Tài liệu chuyên đề này chi tiết hóa [Project.md](Project.md). Khi có xung đột, quyết định Accepted trong ADR/product decision record và `Project.md` được ưu tiên.

## 2. Cách tham khảo các hệ thống lớn

EsquiloSpeak tham khảo các pattern đã được chứng minh, nhưng không sao chép nguyên sản phẩm:

- **Duolingo:** learning path, bài học mới xen kẽ personalized practice, theo dõi điểm tiến bộ và liên kết course với CEFR.
- **Busuu:** bài học ngắn theo tình huống, bốn kỹ năng, placement/checkpoint, community correction và conversation practice có AI.
- **Moodle:** competency framework, learning plan, cohort, evidence và quy trình review năng lực.
- **Anki/SM-2:** review queue và scheduling dựa trên lịch sử ghi nhớ.
- **Apple App Store/Google Play:** subscription lifecycle, renewal, cancellation, billing issue, refund và entitlement.
- **CEFR:** can-do outcome, reception, production, interaction, mediation và proficiency level.
- **WCAG:** khả năng tiếp cận cho người dùng có nhu cầu thị giác, thính giác, vận động, lời nói hoặc nhận thức.

Các phần được suy ra cho EsquiloSpeak từ những pattern này được xem là **đề xuất nghiệp vụ**, trừ khi đã có quyết định Accepted.

## 3. Mục tiêu nghiệp vụ tổng thể

EsquiloSpeak phải giúp người học:

1. Xác định ngoại ngữ, mục tiêu và trình độ phù hợp.
2. Luôn biết nên học hoặc ôn nội dung gì tiếp theo.
3. Học qua hoạt động ngắn nhưng liên kết thành lộ trình có chuẩn đầu ra.
4. Thực hành đọc, nghe, viết, nói và tương tác trong ngữ cảnh thực tế.
5. Nhận phản hồi dễ hiểu, đúng trình độ và có thể hành động ngay.
6. Ghi nhớ lâu hơn thông qua active recall và spaced repetition.
7. Theo dõi tiến bộ bằng năng lực đạt được, không chỉ bằng thời gian sử dụng.
8. Tiếp tục học khi mạng yếu hoặc mất kết nối mà không mất lịch sử.
9. Sử dụng sản phẩm an toàn, minh bạch về dữ liệu, AI và thanh toán.

## 4. Vai trò nghiệp vụ

| Vai trò | Trách nhiệm chính |
| --- | --- |
| Guest learner | Trải nghiệm có giới hạn, học thử và quyết định tạo tài khoản |
| Registered learner | Quản lý lộ trình, tiến độ, review, subscription và dữ liệu cá nhân |
| Child learner | Học trong phạm vi consent, privacy và commerce phù hợp độ tuổi nếu sản phẩm phục vụ trẻ em |
| Parent/guardian | Quản lý consent, quyền mua và báo cáo phù hợp khi mô hình trẻ em được chấp nhận |
| Teacher/mentor | Giao nhiệm vụ, xem evidence, phản hồi và đánh giá năng lực khi được cấp quyền |
| Content author | Soạn course, lesson, exercise, explanation và media |
| Language reviewer | Kiểm tra ngôn ngữ, đáp án, distractor, bản dịch và cultural fit |
| Pedagogy reviewer | Kiểm tra outcome, difficulty, progression và assessment validity |
| Pronunciation/media reviewer | Kiểm tra audio, transcript, accent và chất lượng ghi âm |
| Publisher | Phê duyệt, lên lịch, phát hành, rollback và retire content version |
| Moderator | Xử lý nội dung cộng đồng, abuse, report và appeal |
| Support agent | Xử lý tài khoản, subscription, entitlement, content error và sync incident |
| Organization administrator | Quản lý tổ chức, lớp, cohort, giáo viên, learner và policy |
| Product/analyst | Theo dõi funnel, learning outcome, experiment và chất lượng sản phẩm |
| Finance operator | Đối soát giao dịch, refund, promotion và entitlement exception |
| Security/privacy operator | Xử lý consent, data request, audit, incident và retention |
| System administrator | Quản lý role, policy, configuration và operational state có audit trail |

Một người có thể giữ nhiều vai trò, nhưng quyền phải được tách theo nhiệm vụ và nguyên tắc tối thiểu cần thiết.

## 5. Đối tượng nghiệp vụ cốt lõi

| Đối tượng | Ý nghĩa nghiệp vụ |
| --- | --- |
| Language/locale | Ngôn ngữ nguồn, ngôn ngữ đích, locale giao diện, accent và writing system |
| Curriculum framework | Khung năng lực, level, skill, concept và can-do outcome |
| Course | Lộ trình học cho một cặp ngôn ngữ và nhóm mục tiêu |
| Section/unit | Nhóm lesson theo outcome, chủ đề hoặc giai đoạn năng lực |
| Lesson | Đơn vị học có mục tiêu, nội dung và hoạt động thực hành |
| Exercise | Hoạt động yêu cầu learner tạo hoặc chọn câu trả lời |
| Attempt | Một lần learner thực hiện exercise; được giữ làm lịch sử evidence |
| Feedback | Phản hồi đúng/sai, giải thích, correction và bước cải thiện |
| Learning item/concept | Đơn vị kiến thức hoặc kỹ năng cần theo dõi ghi nhớ/năng lực |
| Mastery state | Ước lượng năng lực hiện tại dựa trên nhiều evidence |
| Review item | Nội dung cần ôn cùng trạng thái và thời điểm đến hạn |
| Assessment | Bài đánh giá có mục tiêu đo lường, rule chấm và kết quả |
| Learning plan | Mục tiêu và tập năng lực learner cần đạt |
| Enrollment | Quan hệ learner tham gia course/track và trạng thái lộ trình |
| Content version | Phiên bản bất biến của nội dung đã phát hành |
| Subscription | Quan hệ thanh toán có lifecycle từ store/provider |
| Entitlement | Quyền sử dụng capability/content tại một thời điểm |
| Organization/class/cohort | Nhóm người dùng, policy, assignment và reporting |
| Support case | Yêu cầu cần điều tra, xử lý và lưu lịch sử |
| Consent record | Bằng chứng learner/guardian đồng ý cho mục đích xử lý dữ liệu cụ thể |

## 6. Bản đồ nhóm nghiệp vụ

```text
Identity and onboarding
  ├── Curriculum and catalog
  ├── Learning path and enrollment
  ├── Lesson, exercise, attempt and feedback
  ├── Mastery, review and personalization
  ├── Listening, speaking, writing and conversation
  ├── Assessment and certification
  ├── Progress, goal and engagement
  └── Offline learning and synchronization

Content operations
  ├── Authoring, review, publish and rollback
  ├── Localization, media and licensing
  └── Quality, report and correction

Business operations
  ├── Subscription, entitlement and promotion
  ├── Community, moderation and support
  ├── School/organization and assignment
  ├── Analytics and experimentation
  └── Privacy, audit and administration
```

## 7. Nghiệp vụ tài khoản, identity và onboarding

### 7.1 Guest và tạo tài khoản

- Cho phép learner xem catalog hoặc học thử theo giới hạn sản phẩm.
- Khi đăng ký, learner có thể hợp nhất tiến độ guest mà không ghi trùng attempt.
- Xác minh email/điện thoại/social identity tùy thị trường.
- Phát hiện và xử lý account trùng, account recovery và account takeover.
- Cho phép đăng xuất từng thiết bị hoặc toàn bộ phiên.

### 7.2 Hồ sơ học tập

- Chọn interface locale, source language và target language.
- Chọn mục tiêu: giao tiếp, học thuật, nghề nghiệp, du lịch, chứng chỉ hoặc sở thích.
- Chọn thời lượng học, lịch nhắc, chế độ âm thanh và accessibility preference.
- Có thể học nhiều ngôn ngữ và chuyển course mà không làm mất lịch sử.
- Hồ sơ học tập khác hồ sơ công khai; dữ liệu riêng tư không tự động hiển thị cho cộng đồng.

### 7.3 Consent và độ tuổi

- Xin consent riêng cho microphone, lưu voice, AI processing, marketing và analytics khi cần.
- Giải thích mục đích, thời hạn lưu và cách rút consent.
- Nếu phục vụ trẻ em, áp dụng guardian consent, giới hạn social/commerce và policy theo thị trường.
- Cho phép export, correction và deletion request theo policy có hiệu lực.

## 8. Nghiệp vụ curriculum, catalog và learning path

### 8.1 Catalog

- Hiển thị course theo source/target language, level, mục tiêu và availability.
- Phân biệt course hoàn chỉnh, course beta, specialized track và organization-only track.
- Mô tả chuẩn đầu ra, prerequisite, thời lượng ước tính và quyền truy cập.
- Không hiển thị content chưa published hoặc không phù hợp audience/locale.

### 8.2 Curriculum

- Framework có version và owner.
- Mỗi outcome liên kết với level, skill, concept và evidence mong đợi.
- Course được chia section/unit/lesson theo progression hợp lý.
- Một ngôn ngữ có thể dùng CEFR; track khác có thể dùng framework phù hợp hơn.
- Course update không được làm mất ý nghĩa của tiến độ đã đạt trên version cũ.

### 8.3 Placement và lựa chọn điểm bắt đầu

- Learner có thể bắt đầu từ đầu, tự khai báo trình độ hoặc làm placement assessment.
- Placement phải lấy mẫu nhiều skill phù hợp, không chỉ từ vựng.
- Kết quả gồm level ước lượng, confidence và điểm bắt đầu được đề xuất.
- Learner được phép chọn điểm thấp hơn; việc bỏ qua nội dung có thể yêu cầu checkpoint.

### 8.4 Learning path

- Path kết hợp lesson mới, checkpoint, review và practice theo điểm yếu.
- Điều kiện mở khóa dựa trên prerequisite và evidence, không chỉ số lần bấm hoàn thành.
- Learner luôn thấy bước tiếp theo và lý do được đề xuất.
- Path có thể cá nhân hóa nhưng vẫn bảo toàn curriculum outcome.

## 9. Nghiệp vụ lesson, exercise, attempt và feedback

### 9.1 Lesson

- Mỗi lesson có outcome, prerequisite, thời lượng ước tính và content version.
- Lesson có thể gồm introduction, example, guided practice, independent practice và summary.
- Hỗ trợ chế độ âm thanh, im lặng và accessibility alternative.
- Learner có thể tạm dừng, tiếp tục hoặc làm lại theo policy.

### 9.2 Nhóm exercise

- Multiple choice và matching.
- Sắp xếp từ/câu.
- Fill-in-the-blank và dictation.
- Translation có mục tiêu rõ, không coi một bản dịch duy nhất là luôn đúng.
- Listening comprehension.
- Reading comprehension.
- Writing response.
- Pronunciation/repetition.
- Speaking response và role-play.
- Conversation theo scenario.
- Review card và recall không gợi ý.

Mỗi loại exercise phải định nghĩa answer policy, hint, partial credit, retry và accessibility behavior.

### 9.3 Attempt

- Mỗi lần trả lời tạo một attempt riêng, không ghi đè lịch sử.
- Attempt gắn với đúng lesson/content version và learner/session.
- Retry do mất mạng không được tạo attempt trùng.
- Có thể ghi correctness, response time, hint usage, confidence và input modality.
- Không dùng tốc độ làm thước đo duy nhất vì có thể bất lợi cho accessibility.

### 9.4 Feedback

- Trả feedback ngay khi điều đó hỗ trợ học; assessment chính thức có thể trì hoãn feedback.
- Giải thích vì sao đúng/sai, không chỉ hiển thị màu.
- Feedback đúng locale, level và không tiết lộ quá mức trước khi learner tự recall.
- Cho phép xem đáp án mẫu, thử lại hoặc đưa item vào review.
- AI feedback phải được đánh dấu, có report/fallback và không được giả làm canonical answer khi không chắc chắn.

## 10. Nghiệp vụ progress, mastery và review

### 10.1 Progress

- Theo dõi trạng thái course, unit, lesson và exercise.
- Phân biệt completion với mastery.
- Hiển thị outcome đã đạt, đang phát triển và cần củng cố.
- Cho phép learner xem lịch sử hoạt động và evidence chính.
- Có thể quy đổi sang score dễ hiểu nhưng phải giải thích ý nghĩa.

### 10.2 Mastery

- Mastery dựa trên nhiều evidence: độ chính xác, độ khó, recency, hint, response time hợp lý và assessment.
- Evidence mới có thể tăng hoặc giảm confidence.
- Mastery theo concept/skill, không chỉ theo lesson.
- Thuật toán thay đổi phải giữ khả năng giải thích và không tùy tiện xóa thành quả learner.

### 10.3 Review và spaced repetition

- Hệ thống tạo review queue theo item đến hạn, item yếu và mục tiêu hiện tại.
- Learner có thể review theo kế hoạch hoặc chủ động chọn phạm vi.
- Trả lời review cập nhật lịch tiếp theo và mastery evidence.
- Item mới, item quên và item ổn định có rule khác nhau.
- Có giới hạn tải review để tránh backlog gây nản, nhưng không che giấu việc còn nội dung cần ôn.

### 10.4 Personal practice

- Chọn nội dung learner đang yếu hoặc sắp quên.
- Không lặp vô hạn một dạng exercise dễ chỉ để tăng engagement.
- Giải thích vì sao một nhóm nội dung được đề xuất.
- Cân bằng review với tiến triển sang nội dung mới.

## 11. Nghiệp vụ nghe, nói, phát âm, viết và hội thoại

### 11.1 Listening

- Audio có transcript, accent, tốc độ và speaker metadata.
- Cho phép nghe lại, giảm tốc khi phù hợp và dùng transcript theo rule bài học.
- Phân biệt lỗi nghe với lỗi từ vựng/ngữ pháp trong feedback.

### 11.2 Pronunciation

- Chỉ ghi âm sau thao tác chủ động và permission rõ ràng.
- So sánh phát âm theo intelligibility và mục tiêu, không ép mọi learner về một accent duy nhất.
- Feedback có thể ở mức utterance, word hoặc sound khi đủ tin cậy.
- Cho phép nghe mẫu, nghe lại bản thân, thử lại và xóa recording theo policy.

### 11.3 Writing

- Hỗ trợ từ câu ngắn đến bài viết theo prompt.
- Feedback bao gồm task completion, clarity, grammar, vocabulary và tone tùy level.
- Phân biệt correction chắc chắn với suggestion phong cách.
- Lưu revision để learner thấy quá trình cải thiện.

### 11.4 Conversation

- Mỗi scenario có mục tiêu giao tiếp và level.
- Learner chọn text/voice mode khi phù hợp.
- Hội thoại có lượt nói, giới hạn, safety filter và cơ chế thoát.
- Feedback có thể tổng hợp cuối phiên để không làm gián đoạn fluency practice.
- AI có thể sai; learner phải có report và canonical reference khi cần.
- Quota/entitlement cho conversation phải minh bạch trước khi bắt đầu.

## 12. Nghiệp vụ assessment và certification

### 12.1 Assessment types

- Placement assessment.
- Unit/section checkpoint.
- Skill assessment cho reading, listening, writing hoặc speaking.
- Progress assessment định kỳ.
- Mock test hoặc certification track.

### 12.2 Quy tắc assessment

- Có blueprint: outcome, skill, difficulty và số lượng item.
- Attempt policy, time limit, pause, retry và accommodation rõ ràng.
- Item exposure và answer leakage được kiểm soát khi assessment có stakes.
- Kết quả phải có score interpretation, confidence/limitation và evidence.
- AI-scored writing/speaking cần evaluation, human review path và appeal khi mức ảnh hưởng cao.

### 12.3 Certificate

- Chỉ cấp khi learner đáp ứng tiêu chí đã công bố.
- Certificate có learner, track, level, thời gian, issuer và verification status.
- Có thể revoke/correct với lý do và audit trail.
- Không tuyên bố certificate tương đương chuẩn bên ngoài nếu chưa được công nhận.

## 13. Nghiệp vụ mục tiêu, engagement và cộng đồng

### 13.1 Goal và habit

- Learner đặt goal theo thời gian, lesson, review hoặc outcome.
- Streak ghi nhận thói quen nhưng không đại diện trực tiếp cho năng lực.
- Cho phép pause/recovery hợp lý và không dùng cơ chế gây áp lực quá mức.
- Notification theo consent, timezone, quiet hours và tần suất.

### 13.2 Achievement và challenge

- Achievement dựa trên hành vi có ý nghĩa và có tiêu chí công khai.
- Challenge không được khuyến khích spam attempt hoặc học đối phó.
- Leaderboard/social comparison phải opt-in khi phù hợp và có privacy control.

### 13.3 Community correction

- Learner có thể gửi writing/speaking exercise để nhận correction từ cộng đồng khi opt-in.
- Người sửa phải biết ngôn ngữ, guideline và giới hạn trách nhiệm.
- Có rating/helpfulness, report, moderation và chống quấy rối.
- Community correction là feedback tham khảo, không tự động trở thành canonical content.

## 14. Nghiệp vụ offline và đồng bộ

- Learner tải content package có version, dung lượng và thời hạn rõ.
- Có thể mở lesson, làm exercise và tạo attempt offline trong phạm vi hỗ trợ.
- Thiết bị lưu hàng đợi thay đổi chưa đồng bộ.
- Khi reconnect, hệ thống chống ghi trùng, giữ lịch sử và trả trạng thái canonical.
- Conflict xử lý theo loại dữ liệu; không dùng last-write-wins cho mọi thứ.
- UI thể hiện rõ offline, đang sync, sync thành công hoặc cần can thiệp.
- Xóa cache không đồng nghĩa xóa progress trên tài khoản.
- Content version bị retire cần policy migration hoặc tiếp tục hoàn thành hợp lý.

## 15. Nghiệp vụ content operations

### 15.1 Authoring

- Tạo curriculum, course, unit, lesson, exercise, answer, explanation và media.
- Gắn owner, locale, source/license, outcome, skill, concept, level và audience.
- Preview theo learner locale/device/mode.
- Kiểm tra bắt buộc trường dữ liệu và semantic rule trước review.

### 15.2 Review

- Language review, pedagogy review, media/pronunciation review và cultural review có thể độc lập.
- Reviewer ghi comment, yêu cầu sửa, approve hoặc reject.
- Author không tự phê duyệt nội dung có rủi ro cao nếu policy yêu cầu separation of duties.
- AI-generated content luôn được đánh dấu và qua human review chịu trách nhiệm.

### 15.3 Publish lifecycle

`draft → in_review → approved → scheduled → published → retired`

- Published version bất biến; sửa tạo version mới.
- Có staged rollout theo course, locale, audience hoặc phần trăm learner.
- Có rollback về version an toàn.
- Learner đang học version cũ được xử lý theo migration policy.
- Publish, rollback và retire có audit trail.

### 15.4 Content quality

- Theo dõi completion, error report, difficulty, discrimination và feedback usefulness.
- Learner có thể báo đáp án sai, audio lỗi, bản dịch không tự nhiên hoặc nội dung không phù hợp.
- Report được triage, điều tra, sửa, review lại và đóng với lý do.
- Lỗi nghiêm trọng có thể unpublish ngay nhưng phải giữ audit/evidence.

## 16. Nghiệp vụ subscription, entitlement và commerce

### 16.1 Product và offer

- Gói miễn phí, premium hoặc organization được mô tả quyền lợi minh bạch.
- Hỗ trợ monthly/yearly, trial, intro offer, promotion và regional pricing khi được quyết định.
- Quota cho AI/conversation/speech phải hiển thị trước khi learner sử dụng.

### 16.2 Purchase lifecycle

- Bắt đầu purchase tại store/provider phù hợp platform.
- Backend xác minh giao dịch trước khi cấp entitlement quan trọng.
- Theo dõi active, grace period, account hold, paused, canceled, expired, refunded và revoked.
- Cancel không đồng nghĩa mất quyền ngay nếu thời hạn đã thanh toán còn hiệu lực.
- Restore purchase và đồng bộ entitlement đa thiết bị.
- Notification từ store được xử lý chống trùng và đối chiếu với source of truth của provider.

### 16.3 Entitlement

- Quyền truy cập được tính từ subscription, offer, organization hoặc grant hỗ trợ.
- Không cho phép UI tự quyết entitlement.
- Mọi cấp/thu hồi ngoại lệ có actor, lý do, thời hạn và audit trail.
- Khi provider lỗi tạm thời, policy phải tránh thu hồi sai quyền lợi hợp lệ.

### 16.4 Refund và support

- Ghi nhận refund request, provider decision, entitlement impact và communication.
- Đối soát purchase, renewal, refund và entitlement incident.
- Không lưu thông tin thanh toán nhạy cảm ngoài phạm vi cần thiết.

## 17. Nghiệp vụ organization, school và class

Phần này chỉ kích hoạt khi product decision chấp nhận mô hình organization.

- Tạo organization, domain, administrator và policy.
- Mời/import learner, teacher; quản lý class/cohort và trạng thái membership.
- Gán learning plan, course, assignment, deadline và accommodation.
- Teacher xem progress/evidence đúng phạm vi lớp được cấp.
- Teacher phản hồi hoặc review competency khi policy cho phép.
- Báo cáo theo learner, class, cohort, outcome và thời gian.
- Learner rời organization phải có policy về ownership, export và giữ tiến độ cá nhân.
- License seat, billing và entitlement của tổ chức tách khỏi subscription cá nhân.
- Admin action và export dữ liệu có audit trail.

## 18. Nghiệp vụ AI và personalization

### 18.1 AI use cases

- Explain answer theo level/locale.
- Writing và speaking feedback.
- Conversation scenario.
- Recommendation và practice generation.
- Hỗ trợ authoring, translation và content QA.
- Support triage có human escalation.

### 18.2 Guardrail nghiệp vụ

- Phân biệt canonical content với output tạo động.
- Hiển thị limitation khi output có thể sai.
- Có consent, data minimization, retention và provider disclosure phù hợp.
- Có quota, latency expectation, fallback và cơ chế tắt tính năng.
- Không tự động publish AI content.
- Model/version thay đổi phải được evaluation trước và giám sát sau phát hành.
- Quyết định ảnh hưởng cao như certificate, entitlement hoặc moderation nghiêm trọng không chỉ dựa vào output AI không được review.

### 18.3 Personalization

- Recommendation dùng goal, level, mastery, review due và bối cảnh sử dụng.
- Learner có thể hiểu hoặc điều chỉnh mục tiêu cá nhân hóa.
- Không dùng thuộc tính nhạy cảm ngoài mục đích đã công bố.
- Có baseline/fallback khi dữ liệu chưa đủ hoặc model lỗi.

## 19. Nghiệp vụ analytics và experimentation

### 19.1 Analytics

- Theo dõi activation, lesson completion, review completion, retention và learning outcome.
- Theo dõi content quality, speech/AI usefulness, sync correctness và entitlement incident.
- Event có định nghĩa, owner, version và privacy classification.
- Không thu raw voice, answer text hoặc PII vào analytics nếu không thật sự cần và được phép.

### 19.2 Experiment

- Mỗi experiment có hypothesis, population, assignment, exposure, primary metric và guardrail.
- Đánh giá learning impact, không chỉ click/time-in-app.
- Có stop condition, exclusion, rollback và lịch sử quyết định.
- Không thử nghiệm dark pattern, làm yếu privacy hoặc gây bất lợi không hợp lý cho nhóm dễ tổn thương.

## 20. Nghiệp vụ support, moderation và trust

### 20.1 Support case

- Learner tạo case theo account, content, learning, sync, subscription, privacy hoặc abuse.
- Case có priority, owner, trạng thái, SLA mục tiêu và communication history.
- Support chỉ xem dữ liệu tối thiểu cần thiết và mọi truy cập nhạy cảm có audit.
- Case được đóng với resolution code; learner có thể reopen/escalate theo policy.

### 20.2 Moderation

- Nhận report cho community content, profile, correction hoặc conversation abuse.
- Triage theo severity; có evidence preservation và safety escalation.
- Action gồm warning, content removal, restriction, suspension hoặc ban.
- Có appeal cho action ảnh hưởng lớn.

### 20.3 Content incident

- Lỗi đáp án, nội dung độc hại, license hoặc privacy có đường xử lý riêng.
- Có khả năng unpublish/rollback nhanh.
- Xác định learner bị ảnh hưởng và sửa progress/assessment nếu cần.

## 21. Nghiệp vụ accessibility và inclusive learning

- Hỗ trợ screen reader, focus order, text scaling, contrast và target size.
- Không dùng màu/âm thanh làm tín hiệu duy nhất.
- Audio có transcript hoặc alternative phù hợp mục tiêu.
- Speaking không tự khởi động microphone; có silent alternative khi outcome cho phép.
- Assessment có accommodation nhưng vẫn bảo toàn construct cần đo.
- Nội dung hỗ trợ nhiều writing system, direction và font requirement.
- Tránh stereotype, ví dụ văn hóa thiếu phù hợp và ngôn ngữ loại trừ.

## 22. Lifecycle nghiệp vụ quan trọng

| Đối tượng | Lifecycle đề xuất |
| --- | --- |
| Account | guest → active → restricted/suspended → closed/deleted |
| Enrollment | proposed → active → paused → completed/withdrawn |
| Lesson progress | not_started → in_progress → completed; có thể review lại |
| Attempt | created_local → submitted → accepted/rejected → evaluated |
| Review item | learning → due → reviewed → relearning/stable → retired |
| Content | draft → in_review → approved → scheduled → published → retired |
| Assessment | assigned/available → started → submitted → evaluated → finalized/appealed |
| Subscription | pending → active → grace/hold/paused → canceled/expired/refunded/revoked |
| Entitlement | scheduled → active → expired/revoked |
| Support case | new → triaged → investigating → waiting → resolved → closed/reopened |
| Organization membership | invited → active → suspended → removed |

Transition phải có điều kiện, actor và audit phù hợp; không cho phép nhảy trạng thái tùy tiện.

## 23. Các luồng end-to-end tiêu biểu

### 23.1 Learner mới

`Mở app → chọn locale/ngôn ngữ → chọn mục tiêu → placement hoặc bắt đầu từ đầu → nhận learning path → hoàn thành lesson đầu tiên → xem feedback/progress`

### 23.2 Phiên học hằng ngày

`Mở Home → xem lesson/review đến hạn → học → gửi attempt → nhận feedback → cập nhật mastery → lên lịch review → hiển thị bước tiếp theo`

### 23.3 Offline/reconnect

`Tải content → mất mạng → học và tạo attempt local → reconnect → gửi hàng đợi → deduplicate → nhận canonical progress/sync cursor → xử lý lỗi nếu có`

### 23.4 Speaking/conversation

`Chọn scenario → xem goal/consent/quota → ghi âm hoặc chat → hoàn thành lượt → phân tích → nhận feedback → lưu evidence cần thiết → xóa/giữ recording theo policy`

### 23.5 Content publish

`Author tạo draft → language/pedagogy/media review → sửa → approve → schedule → publish theo audience → theo dõi quality → rollback hoặc tạo version mới`

### 23.6 Subscription

`Xem offer → purchase tại store → xác minh → cấp entitlement → renewal/grace/hold/cancel/refund event → đồng bộ quyền → support/đối soát`

### 23.7 Organization assignment

`Admin tạo cohort → thêm learner/teacher → gán learning plan/assignment → learner học → teacher xem evidence → review competency → xuất báo cáo`

## 24. Quy tắc nghiệp vụ bất biến

1. Published content version không bị sửa trực tiếp.
2. Attempt đã được chấp nhận không bị mất hoặc ghi đè.
3. Retry cùng một mutation không tạo kết quả nghiệp vụ trùng.
4. Completion không đồng nghĩa mastery.
5. Entitlement không được cấp hoặc thu hồi chỉ dựa trên trạng thái UI.
6. Cancel subscription không tự động thu hồi phần thời gian learner còn quyền sử dụng.
7. AI output không tự trở thành canonical content.
8. Voice/microphone không được thu thập trước consent và thao tác chủ động.
9. Support/admin action nhạy cảm phải có actor, lý do và audit trail.
10. Dữ liệu organization chỉ được xem theo membership và role hợp lệ.
11. Learner phải biết khi đang offline, sync hoặc gặp conflict.
12. Không tuyên bố learning outcome/certificate vượt quá evidence và phạm vi đã công bố.

## 25. Chỉ số nghiệp vụ

| Nhóm | Chỉ số tiêu biểu |
| --- | --- |
| Activation | Hoàn thành hoạt động học có giá trị đầu tiên |
| Learning | Assessment improvement, review retention, mastery recovery |
| Progress | Outcome đạt được, course/lesson completion có chất lượng |
| Retention | D1/D7/D30 learning retention, không chỉ app open |
| Content | Error rate, report rate, difficulty, discrimination, rollback |
| Speech/AI | Useful feedback rate, safety, latency, correction acceptance |
| Offline | Sync success, duplicate prevention, unresolved conflict |
| Community | Correction usefulness, response time, abuse/report rate |
| Commerce | Conversion, renewal, grace recovery, refund, entitlement incident |
| Organization | Assignment completion, competency evidence, active cohort |
| Reliability/support | Crash-free learning, lost-attempt incident, support contact rate |

North-star không nên chỉ là streak, time-in-app hoặc số câu trả lời vì các chỉ số đó không tự chứng minh learner tiến bộ.

## 26. Quyết định còn phải chốt

1. Thị trường, ngôn ngữ và nhóm tuổi đầu tiên.
2. Guest mode, account merge và identity provider.
3. Consumer-only hay có organization ngay trong product model.
4. Curriculum owner, content licensing và moderation jurisdiction.
5. Voice có được lưu không; consent, retention và deletion thế nào.
6. AI quality bar, quota, cost ceiling và human-review boundary.
7. Assessment/certificate track nào được ưu tiên và có công nhận bên ngoài hay không.
8. Community correction có nằm trong baseline hay giai đoạn sau.
9. Subscription model theo quốc gia/platform và quyền lợi từng tier.
10. SLO sản phẩm, support policy và incident severity.

Các câu hỏi này không ngăn việc mô tả mô hình hoàn chỉnh, nhưng phải được chốt trước khi capability tương ứng trở thành yêu cầu triển khai.

## 27. Nguồn tham khảo

### Chuẩn học tập và accessibility

- [Council of Europe — CEFR Companion Volume](https://www.coe.int/en/web/common-european-framework-reference-languages/cefr-companion-volume-and-its-language-versions)
- [Council of Europe — CEFR levels](https://www.coe.int/en/web/common-european-framework-reference-languages/level-%20descriptions)
- [W3C — Web Content Accessibility Guidelines 2.2](https://www.w3.org/TR/WCAG22/)

### Hệ thống học ngôn ngữ và LMS lớn

- [Duolingo — Learning path và personalized practice](https://blog.duolingo.com/right-level-of-difficulty/)
- [Duolingo — Progress score và CEFR](https://blog.duolingo.com/duolingo-score/)
- [Duolingo — CEFR course alignment và bốn kỹ năng](https://blog.duolingo.com/how-are-duolingo-courses-evolving/)
- [Busuu — Course, placement, checkpoint và community correction](https://help.busuu.com/hc/en-us/articles/15936615354641-What-is-Busuu)
- [Busuu — AI conversation và feedback](https://help.busuu.com/hc/en-us/articles/21862192336402-What-are-Busuu-Conversations-and-how-can-they-help-me-learn-a-language)
- [Moodle — Competency learning plans](https://docs.moodle.org/405/en/Learning_plans)
- [Anki — Scheduling](https://docs.ankiweb.net/deck-options.html)
- [Duolingo — Half-Life Regression](https://github.com/duolingo/halflife-regression)

### Subscription lifecycle

- [Google Play — Subscription lifecycle](https://developer.android.com/google/play/billing/lifecycle/subscriptions)
- [Google Play — Purchase lifecycle và entitlement synchronization](https://developer.android.com/google/play/billing/lifecycle)
- [Apple StoreKit — Subscription lifecycle](https://developer.apple.com/documentation/storekit/managing-lifecycle-of-monthly-subscriptions-with-a-12-month-commitment-)

## 28. Quy tắc duy trì tài liệu

- Khi product decision được Accepted, cập nhật phần tương ứng và liên kết tới quyết định.
- Khi thêm capability, phải bổ sung actor, input/output, lifecycle, business rule và failure/support path liên quan.
- Không đưa chi tiết code, database table hoặc endpoint vào tài liệu này.
- Public contract nằm trong `contracts/`; lựa chọn kỹ thuật nằm trong `Tech_Stack_And_Architecture.md` và ADR.
- Review tài liệu cùng thay đổi product scope, contract hoặc policy.
