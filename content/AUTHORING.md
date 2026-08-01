# Content authoring pipeline

Tài liệu này mô tả quy trình content-as-code của Giai đoạn 2. Nguồn authoring
được lưu thành package nhiều file; pipeline validate và compile package sang DTO
của admin API. Dart và Java không thay đổi khi thêm lesson dùng exercise type đã
được runtime hỗ trợ.

## Cấu trúc package

```text
content-package.json
course.json
units/<unit-id>.json
lessons/<lesson-id>.json
media-manifest.json
review-evidence.json
```

- `content-package.json` chỉ chứa đường dẫn tương đối nằm trong package.
- `course.json` sở hữu language pair, proficiency range, outcome và concept catalog.
- Unit khóa thứ tự, prerequisite, outcome và lesson reference.
- Lesson tách `learningItem`, `presentation`, `answerPolicy` và `feedbackRule`.
- Media manifest chỉ chứa metadata/provenance; binary nằm sau object-storage boundary.
- Review evidence dùng checklist có version và được backend lưu trong audit trail.

Template nằm tại [`templates/`](templates/) và package kiểm chứng nằm tại
[`examples/authoring-demo/`](examples/authoring-demo/).

## Validate và preview

Runtime yêu cầu Node.js hiện hành, không cần cài package bổ sung.

```powershell
node content/tools/content-pipeline.mjs validate `
  content/examples/authoring-demo/content-package.json

node content/tools/content-pipeline.mjs preview `
  content/examples/authoring-demo/content-package.json `
  --locale en `
  --out content-preview.html
```

Validator trả `CODE path: message` để author sửa đúng field. Validation gồm:

- cấu trúc, kiểu dữ liệu và ID;
- reference course/unit/lesson/outcome/concept/media;
- duplicate ID và prompt lặp nguyên văn;
- coverage locale bắt buộc;
- answer integrity theo discriminated exercise type;
- outcome/concept coverage;
- checksum, provenance, transcript/alt text và silent-mode metadata;
- review checklist/evidence.

Preview compile về learner-safe shape rồi mới render HTML. `answerPolicy`, đáp án
đúng và `feedbackRule.explanation` không xuất hiện trong preview.

## Import hoặc cập nhật draft

CLI chỉ nhận token qua biến môi trường và không ghi token vào artifact/log:

```powershell
$env:ESQUILO_CONTENT_TOKEN = '<content-admin-token>'
node content/tools/content-pipeline.mjs import-draft `
  content/examples/authoring-demo/content-package.json `
  --base-url http://localhost:8080
```

Chỉ version ở trạng thái `draft` được thay thế. Published version bất biến; thay
đổi nội dung phải tăng `course.version`, cập nhật reference và import thành draft mới.

## Review, publish và vận hành lifecycle

```powershell
node content/tools/content-pipeline.mjs transition <package> review --base-url <url>
node content/tools/content-pipeline.mjs transition <package> approved --base-url <url>
node content/tools/content-pipeline.mjs transition <package> published --base-url <url>
node content/tools/content-pipeline.mjs transition <package> scheduled `
  --effective-at 2026-08-02T01:00:00Z --base-url <url>
node content/tools/content-pipeline.mjs transition <package> retired --base-url <url>
node content/tools/content-pipeline.mjs rollback <package> <target-version> --base-url <url>
```

Khi vào `review`, backend yêu cầu đủ các check: schema, references, pedagogy,
language, media-accessibility, answer-integrity và preview. Mỗi check phải `passed`
và có evidence. Schedule cần thời điểm tương lai. Publish version mới tự retire
version đang publish; rollback chỉ nhận version từng published rồi retired.

`compatibilityVersion` chỉ tăng khi delivery/attempt semantics không còn tương
thích với tiến độ cũ. Sửa câu chữ, distractor hoặc media nhưng giữ semantics không
tự động tăng compatibility version. Attempt/progress cũ vẫn gắn với lesson/content
version ban đầu và backend tiếp tục chấm version retired tương thích.

## Khi nào cần admin web hoặc CMS

Tiếp tục dùng content-as-code cho đến khi có số liệu cho thấy ít nhất một trong
các điều kiện sau kéo dài qua hai chu kỳ phát hành:

- hơn 10 author không kỹ thuật cần làm việc đồng thời và Git review là bottleneck;
- trên 50 thay đổi content/tuần khiến lead time từ draft tới review vượt hai ngày;
- translation/media workflow cần assignment, SLA và quyền field-level mà Git không đáp ứng;
- tỷ lệ lỗi thao tác package vượt 5% dù validator và template đã được cải thiện;
- compliance yêu cầu approval segregation hoặc audit UI ngoài khả năng API hiện tại.

CMS chỉ được mở sau khi xác định owner, authorization, audit, deployment và chi phí
đồng bộ với contract content-as-code. CMS phải dùng cùng schema/validator/API, không
tạo một nguồn chuẩn thứ hai.
