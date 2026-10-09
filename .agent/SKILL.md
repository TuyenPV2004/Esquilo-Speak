---
name: esquilospeak-workspace
description: Use when working inside the EsquiloSpeak repository for review, architecture, documentation, planning, Flutter, Spring Boot, Python AI/speech, Next.js admin, contracts, data, security, infrastructure, or validation.
---

# EsquiloSpeak Workspace Skill

## Purpose

Keep work aligned with EsquiloSpeak's full-product scope, source-of-truth rules, architecture boundaries, approval workflow and validation expectations.

## Source of truth

Read relevant sources in this order:

1. Accepted ADR files under `docs/decisions/`.
2. `docs/shared/Project.md` for product scope and project-wide product decisions.
3. `docs/architecture/Tech_Stack_And_Architecture.md` for technology and system architecture.
4. `docs/architecture/Repository_Structure.md` for repository layout and dependency rules.
5. Machine-readable contracts under `contracts/` when they exist.
6. `docs/plans/Ke_Hoach_1.md` and `docs/plans/Ke_Hoach_2.md` for implementation order, phase status and quality gates.
7. Root and module-level `AGENTS.md` files.
8. Task-specific documents under `docs/`.
9. Existing implementation patterns.
10. `docs/shared/Esquilo_Speak.md` only as discovery context.

Do not reference, infer or recreate undocumented source files unless the user explicitly requests them.

## Product guardrails

- Treat EsquiloSpeak as a complete, evolvable language-learning platform, not a scope-limited prototype.
- Preserve multi-language and multi-locale capability across schema, UI, content and API.
- Keep the core learning loop reliable: lesson, exercise, feedback, progress, mastery, review and offline sync.
- Support advanced capabilities such as speech, AI, assessment, commerce, CMS and analytics through explicit domain boundaries.
- Do not equate a complete product with deploying every logical domain as an independent service immediately.
- Add infrastructure or distributed-system complexity only when requirements, ownership, scale or failure isolation justify it.

## Architecture boundaries

- Mobile direction: Flutter + Dart with Android as the current build, test and
  release target. Retain shared-code compatibility where practical, but defer
  native iOS work until the developer explicitly reprioritizes it.
- Admin direction: Next.js + TypeScript.
- Core backend direction: Java + Spring Boot with verified domain modules.
- AI/speech direction: Python service with provider adapters and evaluation boundaries.
- Mobile and admin call backend through the client API/API Gateway, never directly access internal databases or AI providers.
- Use REST/JSON and OpenAPI for client/public contracts; use event schemas for asynchronous integration.
- Preserve idempotency, content version and sync cursor metadata.
- Keep data ownership per deployable unit; do not create cross-service physical foreign keys.

## Review mode

When the user asks to review, check, inspect, audit, evaluate or compare:

1. Inspect relevant files and surrounding context.
2. Do not edit unless the user explicitly asks to apply changes.
3. Report summary, scope, findings, exact locations, impact, fix, trade-offs and next action.
4. Separate confirmed issues from assumptions and design preferences.

## Change approval

Do not modify source code without explicit developer approval. Before code changes, state:

1. The requested change or issue.
2. Why the change is needed.
3. Exact files expected to change.
4. Intended implementation.
5. Validation commands.

Documentation changes may proceed when the user's latest request explicitly asks to create, edit, clean or fix documentation.

## Roadmap alignment

- Read the relevant phase and gate in `docs/plans/Ke_Hoach_1.md` and `docs/plans/Ke_Hoach_2.md` before implementation.
- Complete the approved backend scope and its validation gate before the
  corresponding Android frontend work.
- Do not mark a checklist item complete without an artifact and validation
  evidence; leave partial or unverified work open with a concise note.
- Update the relevant plan and `docs/process/Development_Change_Log.md` when work changes
  roadmap status, dependencies or priorities.
- Do not schedule native iOS work unless the developer explicitly changes the
  current Android-first priority.

## Documentation

- Keep product overview, technology/architecture, and repository layout in their dedicated documents; do not merge them into one catch-all file.
- Accepted long-term decisions belong in `docs/decisions/` and link back to the document responsible for that scope.
- Treat `docs/shared/Esquilo_Speak.md` as discovery material, not an implementation contract.
- Place documents in the functional groups defined by `docs/README.md`; do not add a new top-level Markdown document when an existing group applies.
- Keep direct links to official/reputable references for technical recommendations.
- Mark self-derived design decisions clearly.

## Validation

Run the narrowest meaningful checks available:

- Mobile: `flutter analyze`, `flutter test`.
- Backend: Gradle test and Spring Modulith boundary verification.
- Web: lint, typecheck, unit and end-to-end tests provided by the project.
- Python: lint, typecheck, unit/integration/evaluation tests provided by the project.
- Contracts: lint and backward-compatibility checks.
- Infrastructure: Compose config, Terraform validate/plan and manifest policy checks.
- Documentation: UTF-8, heading structure, code fences, local links, stale placeholders and obsolete source references.

If a check cannot run, report the exact reason.

## Final response

When files change, summarize:

- Files changed and why.
- Validation commands run.
- Remaining risks or unverified areas.
- Whether the user should review the diff.
