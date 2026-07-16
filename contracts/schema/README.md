# First learning vertical slice — content schema

These JSON Schema Draft 2020-12 documents define the versioned learning content used by the first vertical slice.

## Files

- `common.schema.json`: shared identifiers, locale, localized text, lifecycle and ownership metadata.
- `language.schema.json`: one enabled learning language in the catalog.
- `course.schema.json`: one language-pair course and its ordered lesson IDs.
- `lesson.schema.json`: one lesson containing multiple-choice exercises.
- `lesson.example.json`: minimal valid lesson example.

## Semantic rules outside JSON Schema

- Every `correctOptionId` must identify exactly one option in the same exercise.
- Exercise IDs and option IDs must be unique inside their containing lesson/exercise.
- A published `(content ID, version)` is immutable; edits create a new version.
- `lesson.courseId` must reference an existing course, and the course must include the lesson ID.
- Content exposed to learners must be `published`; draft lifecycle validation belongs to the publishing workflow.
- All learner-visible text required by a release must contain the release's supported locales.
- Owner, license and source information must be reviewed before publishing.

The API contract is `../openapi/esquilospeak-learning-v1.yaml`.

## Standards

- [JSON Schema Draft 2020-12](https://json-schema.org/draft/2020-12)
- [BCP 47 language tags](https://www.rfc-editor.org/rfc/bcp/bcp47.txt)
