# ADR-008: Versioned proficiency frameworks

- Status: Accepted
- Date: 2026-07-31

## Context

The first course is Vietnamese-to-English at CEFR A1, but EsquiloSpeak is a
multi-target-language product. Later courses may use another CEFR level or a
language-specific framework. Treating `A1` as a global enum would couple course
content, placement evidence, completion records, API clients, and UI copy to the
first English course.

## Decision

- A proficiency framework is versioned data identified by `frameworkCode` and
  `frameworkVersion`; it may optionally be scoped to a target language.
- A proficiency level is identified by `levelCode` within one exact framework
  version and has an ordinal plus localized title/descriptor.
- Every newly authored course version declares an entry and target level in one
  framework version. The database validates both references.
- Placement definitions are course-specific data. Attempts and completion
  records preserve the exact framework version and level used as evidence.
- Contracts and application code use generic proficiency references. They must
  not branch on CEFR or enumerate `A1`, `A2`, or other framework-specific codes.
- CEFR 2020 and its Pre-A1–C2 levels are initial seed data. The current
  Vietnamese-to-English course targets A1; this is content configuration, not a
  system default.

## Consequences

- Adding A2/B1 or a Chinese-specific framework requires new validated data and
  content, not changes to the Java/Dart domain model.
- Framework version changes are explicit; historical assessment evidence keeps
  its original semantics.
- The learner journey must select an active course before loading a placement
  assessment. Full source/target-language selection remains a product roadmap
  item in Giai đoạn 1.
- Existing integrations must adopt OpenAPI 0.6.0 fields and pass `courseId` when
  requesting placement and `assessmentId` when submitting it.

