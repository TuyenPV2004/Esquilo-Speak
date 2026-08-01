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

## Authoring pipeline

- [`AUTHORING.md`](AUTHORING.md): quy trình package, validate, preview, review,
  import/publish, compatibility và tiêu chí chỉ xây CMS khi có bottleneck đo được.
- [`templates/`](templates/): template JSON cho package, course, unit, lesson,
  exercise, media manifest và review evidence.
- [`examples/authoring-demo/`](examples/authoring-demo/): package learner-ready nhỏ
  dùng làm contract/tooling fixture.
- [`tools/content-pipeline.mjs`](tools/content-pipeline.mjs): validator, compiler,
  learner-safe preview và HTTP lifecycle CLI.

Các tài liệu course mô tả curriculum đã chốt ở Giai đoạn 1. Pipeline Giai đoạn 2
biến package JSON thành draft backend và preview; lesson learner-ready đầy đủ của
Unit 1 thuộc Giai đoạn 4. Không sao chép nội dung course vào Dart hoặc Java.
