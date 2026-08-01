# EsquiloSpeak content-as-code

Thư mục này chứa source of truth cho curriculum và nội dung học trước khi nội
dung được nhập vào lifecycle `draft → review → approved → scheduled → published`.

## Course hiện hành

- [`course-en-for-vi/Curriculum_A1.md`](courses/course-en-for-vi/Curriculum_A1.md):
  persona, outcome, course map và inventory English A1 cho người Việt.
- [`course-en-for-vi/Unit_1_Specification.md`](courses/course-en-for-vi/Unit_1_Specification.md):
  đặc tả 5 lesson của Unit 1 dùng để kiểm chứng authoring pipeline và exercise engine.
- [`course-en-for-vi/Content_Standards.md`](courses/course-en-for-vi/Content_Standards.md):
  quy tắc biên soạn, feedback, media, safety, accessibility và acceptance rubric.
- [`course-en-for-vi/unit-1-v2/`](courses/course-en-for-vi/unit-1-v2/): package
  Unit 1 version 2 gồm 5 lesson, 45 exercise, media manifest, review evidence,
  compiled admin fixture và learner-safe preview.

## Authoring pipeline

- [`AUTHORING.md`](AUTHORING.md): quy trình package, validate, preview, review,
  import/publish, compatibility và tiêu chí chỉ xây CMS khi có bottleneck đo được.
- [`templates/`](templates/): template JSON cho package, course, unit, lesson,
  exercise, media manifest và review evidence.
- [`examples/authoring-demo/`](examples/authoring-demo/): package learner-ready nhỏ
  dùng làm contract/tooling fixture.
- [`tools/content-pipeline.mjs`](tools/content-pipeline.mjs): validator, compiler,
  learner-safe preview và HTTP lifecycle CLI.
- [`tools/generate-unit-one-media.ps1`](tools/generate-unit-one-media.ps1): tái tạo
  10 tệp WAV Unit 1 bằng Microsoft SAPI/Zira; generator JSON sau đó ghi checksum,
  duration và provenance từ chính binary này.

Các tài liệu course mô tả curriculum đã chốt ở Giai đoạn 1. Pipeline biến package
JSON thành draft backend và preview; Unit 1 V2 là vertical slice Giai đoạn 4 và
không được sao chép nội dung course vào Dart hoặc Java.
