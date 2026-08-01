# Versioned curriculum and learner-delivery schemas

These JSON Schema Draft 2020-12 documents define content-as-code authoring
packages and learner-safe delivery payloads.

## Files

- `common.schema.json`: shared identifiers, locale, localized text, lifecycle and ownership metadata.
- `language.schema.json`: one enabled learning language in the catalog.
- `authoring-package.schema.json`: safe relative references composing one package.
- `course.schema.json`: immutable language-pair course version, outcomes, concepts and ordered unit IDs.
- `unit.schema.json`: ordered unit with outcome, prerequisite and lesson references.
- `lesson.schema.json`: source authoring model separating learning item,
  presentation, answer policy and feedback rule for discriminated exercise types.
- `media-manifest.schema.json`: media provenance, checksum and accessibility metadata.
- `review-evidence.schema.json`: versioned publish-review checklist evidence.
- `lesson-delivery.schema.json`: the public lesson response without scoring data.
- `lesson.example.json`: minimal valid lesson example.

`answerPolicy` and `feedbackRule.explanation` are authoring-only. The pipeline
compiles them to the current admin API DTO while learner preview/delivery excludes
all scoring answers and explanations.

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
- Exact prompt repetition, outcome/concept coverage, review evidence and media
  accessibility are semantic checks performed by `content/tools/content-pipeline.mjs`.

The API contract is `../openapi/esquilospeak-learning-v1.yaml`.

## Standards

- [JSON Schema Draft 2020-12](https://json-schema.org/draft/2020-12)
- [BCP 47 language tags](https://www.rfc-editor.org/rfc/bcp/bcp47.txt)
