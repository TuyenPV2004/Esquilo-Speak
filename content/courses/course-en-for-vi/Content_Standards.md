# English A1 content standards

## 1. Phạm vi

Tài liệu này áp dụng cho `course-en-for-vi` và khóa các quyết định pedagogy cần
thiết trước khi mở rộng content schema/exercise engine. Quy tắc dùng chung cho
course khác chỉ được tái sử dụng sau review; không biến lựa chọn English A1 thành
global application constant.

## 2. Lesson template

Mỗi lesson dài khoảng 5–8 phút, thường có 8–12 exercise/task và đi theo flow:

1. **Warm-up:** 1–2 retrieval item từ prerequisite; không dạy content mới.
2. **Introduction:** đặt 5–7 item/cấu trúc mới trong một ngữ cảnh giao tiếp rõ.
3. **Guided practice:** 3–4 task recognition/reception với feedback tức thì.
4. **Independent practice:** 2–3 task recall, production hoặc interaction; giảm gợi ý.
5. **Mistake review:** chọn lỗi có giá trị học, đổi presentation hoặc context.
6. **Summary:** nêu can-do đã luyện, evidence chính và bước tiếp theo; không chỉ
   hiển thị XP/phần trăm.

Checkpoint không dùng introduction và không thêm item mới.

## 3. Difficulty và cognitive load

- Mỗi task kiểm tra một mục tiêu chính; distractor không được tạo khó bằng mẹo chữ.
- Bắt đầu bằng context rõ và input ngắn, sau đó giảm scaffold hoặc thay biến thể.
- Tối đa 5–7 item/cấu trúc mới trong lesson; chia nhóm khi dạy số hoặc alphabet.
- Một item cần tối thiểu hai lần tái xuất hiện có khoảng cách trước production
  không gợi ý, trừ khi item chỉ dùng làm optional exposure.
- Audio A1 dùng phát âm rõ và tốc độ chậm tự nhiên; không kéo giãn âm phi tự nhiên.
- Difficulty metadata mô tả demand (`recognition`, `recall`, `production`,
  `interaction`) và input complexity, không chỉ là `easy/medium/hard` chủ quan.

## 4. Hint, retry và feedback policy

### Hint ladder

1. Nhắc lại mục tiêu hoặc instruction bằng câu ngắn.
2. Giảm số lựa chọn hoặc làm nổi phần context liên quan mà không lộ đáp án.
3. Cung cấp mẫu tương tự, không phải chính câu trả lời.
4. Reveal đáp án chỉ sau một attempt có evidence hoặc khi learner chủ động bỏ qua.

### Retry

- Cho retry sau feedback; không buộc learner lặp vô hạn để tiếp tục.
- First response, hint usage và corrected response là evidence riêng.
- Task kỹ năng nói/viết cho phép thử lại trước khi gửi nếu chưa tạo server attempt.
- Retry mạng giữ nguyên idempotency key; retry học tập tạo attempt/evidence mới.

### Feedback

- Bắt đầu bằng kết quả có thể hành động: đúng meaning nào, sai ở đâu, thử gì tiếp.
- Không dùng chỉ `Đúng/Sai`; explanation ngắn, đúng ui locale và đúng level.
- Không chê accent, trí thông minh hoặc gán phẩm chất cho người học.
- Với đáp án tương đương, feedback không khẳng định chỉ một cách nói là đúng.
- Learner delivery không chứa answer key hoặc explanation trước khi attempt được chấm.

## 5. Scoring và partial credit

- **Meaning-first:** meaning/task completion là trọng số chính ở A1.
- **Form evidence:** grammar, spelling và pronunciation được ghi riêng khi có giá
  trị chẩn đoán; lỗi không cản meaning không mặc định nhận 0 điểm.
- **Multiple choice/true-false:** binary theo option contract, nhưng distractor
  phải kiểm tra outcome chứ không chỉ hình thức bề mặt.
- **Ordering/fill/dictation:** normalized answer policy phải khai báo case,
  whitespace, punctuation, contraction và biến thể được chấp nhận.
- **Writing/speaking:** rubric tối thiểu gồm task completion, intelligibility,
  target form và repair; provider score không được là quyết định duy nhất.
- **Partial credit:** chỉ dùng khi rubric/version đã khai báo; learner phải thấy
  phần đạt và phần cần sửa. Không cộng partial credit ngầm ở client.
- Scoring policy, normalization và rubric version thuộc authoring content hoặc
  versioned policy; server là nguồn canonical.

## 6. Content style EN/VI

### English target content

- Dùng English quốc tế dễ hiểu; chấp nhận biến thể thông dụng khi không đổi outcome.
- Câu mẫu ngắn, tự nhiên và có context; tránh câu đúng ngữ pháp nhưng không ai dùng.
- Contraction thông dụng (`I'm`, `what's`, `can't`) được dạy cùng expanded form
  khi giúp nhận biết, không buộc một dạng duy nhất trong production.
- Không trình bày accent Anh/Mỹ như chuẩn đạo đức hoặc năng lực; media có thể đa
  dạng accent dễ hiểu sau khi learner đã nhận biết form cơ bản.

### Vietnamese instructional content

- Viết rõ, ngắn, xưng hô trung tính; ưu tiên động từ hành động: “Chọn”, “Nghe”,
  “Nói”, “Viết”.
- Giải thích meaning/function trước thuật ngữ. Nếu cần thuật ngữ, kèm ví dụ.
- Không dịch word-for-word khi làm sai meaning hoặc usage.
- Dấu câu và chính tả tiếng Việt đầy đủ; không trộn raw domain code vào UI.

### Naming và identity

- Dùng tên đa dạng, dễ phát âm ở level hiện tại; không gắn tên/quốc tịch với định kiến.
- Người học không phải cung cấp tên, tuổi, email hoặc thông tin thật để hoàn thành bài.
- Scenario dùng persona giả định khi xử lý dữ liệu cá nhân.

## 7. Cultural và safety review

- Không mặc định giới, quan hệ gia đình, tôn giáo, tình trạng hôn nhân, nghề nghiệp
  hoặc khả năng tài chính.
- Tránh yêu cầu tiết lộ thông tin nhạy cảm; luôn có lựa chọn persona/skip phù hợp.
- Không dùng nội dung bạo lực, tình dục, miệt thị, thao túng, cờ bạc hoặc chất gây
  nghiện trong course nền tảng nếu không có lý do học tập và review riêng.
- Địa danh, tiền tệ và phép lịch sự phải có context; không mô tả một văn hóa là
  “đúng” và văn hóa khác là “sai”.
- AI chỉ tạo draft; canonical content cần human language/pedagogy review.
- Content report phải giữ content reference/version và không thu dữ liệu cá nhân
  không cần thiết.

## 8. Media guideline

### Audio

- Mỗi asset có media ID, locale BCP 47, speaker/voice provenance, license,
  transcript, duration, checksum và ngày/version tạo.
- Giọng đọc rõ, tự nhiên, không dùng tốc độ phi thực tế; bản chậm nếu có là asset
  hoặc playback option riêng và phải được gắn nhãn.
- Không dùng raw learner voice làm canonical content hoặc training data.
- Chuẩn production về codec/loudness được chốt khi chọn media pipeline ở Giai
  đoạn 2/4; không nhúng binary vào JSON content.

### Image

- Chỉ dùng khi hình ảnh đóng góp meaning; decorative image phải được đánh dấu để
  assistive technology bỏ qua.
- Có alt text EN/VI mô tả thông tin cần làm task, không tiết lộ đáp án.
- Ghi nguồn, quyền sử dụng, chỉnh sửa và model release nếu có người thật.
- Không dùng màu hoặc đặc điểm hình thể làm tín hiệu duy nhất.

### Fallback

- Mọi task audio có transcript/text alternative và silent-mode path.
- Nếu media tải lỗi, learner có retry và đường học không phụ thuộc media khi
  outcome cho phép; task bắt buộc listening phải báo rõ chưa thể hoàn thành thay
  vì tự chấm sai.

## 9. Accessibility requirements

- Instruction, label và feedback có semantics đầy đủ ở EN/VI.
- Focus order theo flow; lỗi đưa focus tới summary trước, field sau.
- Tap target và contrast theo design system; kiểm tra text scale 200%.
- Không giới hạn thời gian cho task A1 thông thường. Task có timing phải có
  accommodation và không dùng speed làm mastery duy nhất.
- Drag/drop, swipe, microphone và audio đều có phương thức thay thế khả dụng.
- Transcript/caption không chứa answer key ngoài thời điểm policy cho phép.
- Screen reader phải đọc trạng thái selected/corrected/progress mà không lặp
  feedback gây nhiễu.

## 10. Acceptance rubric

Mỗi lesson/checkpoint phải được review theo bảng sau trước khi chuyển `approved`.
Một mục **Blocker** chưa đạt sẽ chặn publish; **Major** cần sửa hoặc có risk
acceptance được ghi nhận.

| Nhóm | Tiêu chí | Mức |
| --- | --- | --- |
| Outcome | Can-do quan sát được, phù hợp A1 và khớp evidence | Blocker |
| Progression | Prerequisite/item introduction/reappearance đúng inventory | Blocker |
| Language EN | Câu tự nhiên, meaning chính xác, biến thể hợp lệ được xử lý | Blocker |
| Instruction VI | Rõ, ngắn, không dịch sai hoặc lộ đáp án | Blocker |
| Answer integrity | Answer/rubric đúng; learner delivery không lộ scoring data | Blocker |
| Pedagogy | Có retrieval, guided và independent evidence; không chỉ recognition | Blocker |
| Difficulty | New load và distractor hợp lý; không tạo khó bằng mẹo | Major |
| Feedback | Có hành động tiếp theo, đúng locale, không phán xét | Major |
| Cultural/safety | Không định kiến, không ép dữ liệu thật, scenario phù hợp | Blocker |
| Media | License/provenance/transcript/checksum/alt text đầy đủ | Blocker khi có media |
| Accessibility | Silent path, semantics, 200% text, alternative interaction | Blocker |
| Offline/version | Reference/version/checksum đầy đủ; retry không nhân đôi attempt | Blocker |
| QA | Schema, semantic validator, preview và regression tương ứng pass | Blocker khi tooling tồn tại |

### Review evidence tối thiểu

- Reviewer và vai trò: language, pedagogy, media/accessibility nếu liên quan.
- Content ID/version và ngày review.
- Checklist result, finding, owner và trạng thái xử lý.
- Preview/build/test evidence tương ứng.
- Quyết định approve/reject; không sửa published version tại chỗ.

## 11. Điều kiện đánh giá lại

Review lại tài liệu khi thay target persona/level, có dữ liệu beta cho thấy
completion hoặc learning outcome không đạt, thêm exercise modality mới, chọn
production speech/media provider, hoặc phát hiện policy gây bất lợi cho một nhóm
người học. Thay đổi phải version hóa và không diễn giải lại evidence lịch sử.

