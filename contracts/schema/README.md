# Versioned curriculum and learner-delivery schemas

These JSON Schema Draft 2020-12 documents define authoring content and
learner-safe delivery payloads used by the first vertical slice.

## Files

- `common.schema.json`: shared identifiers, locale, localized text, lifecycle and ownership metadata.
- `language.schema.json`: one enabled learning language in the catalog.
- `course.schema.json`: one immutable language-pair course version and its ordered unit IDs.
- `unit.schema.json`: one ordered curriculum unit.
- `lesson.schema.json`: authoring model for multiple-choice and true/false exercises.
- `lesson-delivery.schema.json`: the public lesson response without scoring data.
- `lesson.example.json`: minimal valid lesson example.

The authoring schema contains `correctOptionId` or `correctAnswer` plus
`explanation`. The delivery schema excludes all scoring answers and explanations
so a client cannot read them before submitting an attempt.

## Semantic rules outside JSON Schema

- Every `correctOptionId` must identify exactly one option in the same exercise.
- Exercise IDs and option IDs must be unique inside their containing lesson/exercise.
- A published `(content ID, version)` is immutable; edits create a new version.
- `lesson.courseId`, `courseVersion`, and `unitId` must reference the same versioned curriculum tree.
- Content exposed to learners must be `published`; draft lifecycle validation belongs to the publishing workflow.
- All learner-visible text required by a release must contain the release's supported locales.
- Owner, license and source information must be reviewed before publishing.
- Media fields are metadata references only. Binary storage is introduced behind
  an object-storage boundary when production audio or images are added.

The API contract is `../openapi/esquilospeak-learning-v1.yaml`.

## Standards

- [JSON Schema Draft 2020-12](https://json-schema.org/draft/2020-12)
- [BCP 47 language tags](https://www.rfc-editor.org/rfc/bcp/bcp47.txt)
