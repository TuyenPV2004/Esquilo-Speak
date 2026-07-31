# ADR-004 — P0 product, privacy, and service decisions

- Status: Accepted
- Date: 2026-07-30
- Scope: Sprint B / Phase 4

## Context

The first learning slice is closed, but identity/profile implementation depends
on explicit product and privacy decisions. The product owner has selected
Vietnamese-to-English as the default learning pair, does not want to bind the
product to a first country, and does not impose a minimum learning age.

A market-neutral design cannot safely imply unrestricted public distribution.
Likewise, supporting learners of every age cannot imply identical account,
tracking, or voice-processing behavior for minors. Sprint B therefore needs
operational defaults that allow backend work to start while retaining a
separate public-release compliance gate.

## Decision

1. Keep the product country-neutral during P0 and limit distribution to
   internal/closed testing until launch countries pass a separate release
   review.
2. Use `vi` as the default source language, `en` as the default target language,
   and Vietnamese as the default UI locale. Keep all language pairs
   configuration-driven.
3. Set no minimum age for learning. Collect no full birth date. When account or
   synchronized processing needs an age decision, use the neutral bands
   `under_16`, `16_17`, and `adult`.
4. Restrict under-16 learners to a privacy-preserving guest experience unless a
   compliant guardian-consent flow is implemented and accepted.
5. Use pseudonymous guests with a 90-day inactivity lifetime and an explicit,
   transactional, idempotent one-guest-to-one-account merge.
6. Record consent by purpose and policy version. P0 does not collect, upload, or
   retain voice.
7. Provide asynchronous, auditable export and deletion workflows with the
   targets and retention periods defined in `docs/plans/P0_GATE.md`.
8. Keep subscription and entitlement outside P0. Add commerce only after a P1
   product decision and use platform-compliant billing for Android digital
   benefits.
9. Measure learning evidence as the primary outcome and use the initial
   reliability targets in the P0 gate as internal hypotheses to rebaseline
   after representative data exists.
10. Offer email or web-form support in Vietnamese and English with the response
    targets defined in the P0 gate.

## Consequences

- Sprint C identity/profile contract and implementation may begin.
- Country-specific public distribution, tax, billing, privacy, and child-safety
  compliance remain release blockers rather than hidden assumptions.
- Guest learning remains accessible without collecting contact details.
- Account synchronization for an under-16 learner remains unavailable until a
  guardian-consent design is separately reviewed and accepted.
- Speech and subscription work cannot enter P0 incidentally.
- Retention enforcement, export/deletion state, and SLO instrumentation become
  testable delivery requirements rather than policy-only text.
- The 16-year boundary is a conservative product control and must be reviewed
  for each public launch jurisdiction; it is not a claim of universal legal
  sufficiency.

## Source of truth

Detailed invariants, retention periods, acceptance criteria, service targets,
and the dependency-ordered backlog are maintained in
`docs/plans/P0_GATE.md`.

## Compliance references

These references constrain implementation and release review; they do not
replace jurisdiction-specific legal advice:

- [Google Play — Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Google Play — User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311)
- [Google Play — Families data practices](https://support.google.com/googleplay/android-developer/answer/11043825)
- [Google Play — Target audience and content](https://support.google.com/googleplay/android-developer/answer/9867159)
- [Google Play — Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738)
- [Vietnam Law No. 91/2025/QH15 on Personal Data Protection](https://congbao.chinhphu.vn/van-ban/luat-so-91-2025-qh15-45578.htm)
