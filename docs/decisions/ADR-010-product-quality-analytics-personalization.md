# ADR-010: Product-quality analytics and versioned personalization

- Status: Accepted
- Date: 2026-08-02
- Decision owners: Product, learning content, backend, Android
- Scope: Giai đoạn 8 of `docs/plans/Ke_Hoach_2.md`
- Amends: ADR-006 Decision 11 (first-party product analytics only)

## Context

The A1 course, daily loop and reusable practice modes now produce canonical
attempt, completion, mastery and review evidence. The product needs traceable
quality metrics and better recommendations without optimizing for XP or time in
app, copying sensitive learning content into telemetry, or making learning depend
on an analytics vendor.

## Decision

1. Canonical learning tables are the source for outcome metrics whenever possible.
   Optional client events are used only for otherwise unobservable funnel boundaries,
   such as a presentation followed by abandonment.
   Cross-module reporting access is exposed through explicit, read-only
   `product_quality_*` database views owned by this read model. Product quality does
   not query another module's table name in application code and cannot mutate
   learning, mastery, review, engagement or support records through those views.
2. Product analytics uses a first-party, authenticated batch endpoint. Event names,
   event version and scalar attributes are allowlisted. Raw answers, prompt text,
   free-form feedback, voice, tokens and contact identifiers are rejected by contract.
3. `operational_telemetry` consent is checked on device and again on ingestion. Events
   expire after 30 days under P0 policy. Withdrawal stops new events; account deletion
   removes active analytics data through the privacy participant boundary.
4. Dashboard metrics always expose source and sample size. A consented funnel must not
   be presented as the behavior of all learners. D1/D7 targets are not set before a
   representative closed-beta cohort exists.
5. Content quality is an auditable queue, not only a chart. Reports, low-correctness
   anomalies and low feedback-usefulness signals resolve to a content reference and a
   triage state.
6. Recommendation policy is stored and returned with a version and explanation code.
   V1 deterministically orders due review, weakest mastery, continue learning and the
   no-evidence start fallback. Mobile retains the same bounded local fallback when the
   recommendation API or network is unavailable.
7. Any recommendation/scheduler candidate requires a versioned offline dataset,
   explicit acceptance criteria and a rollback target before promotion. An experiment
   cannot trade learning outcome, attempt durability, safety or privacy for engagement.

## Consequences

- The product can answer which lesson/exercise generated an anomaly without collecting
  raw learner responses.
- Completion and correctness remain measurable when optional telemetry is disabled;
  funnel and abandonment measurements correctly have a smaller consented sample.
- Rule evolution has migration and rollback overhead, but is reproducible and reviewable.
- The minimum internal dashboard is an operations API. A separate admin UI remains a
  later decision and does not justify adding a new frontend stack in this stage.

## Verification

- `ProductQualityApiIntegrationTest` covers consent, allowlist, deduplication, retention,
  dashboard, queue traceability and versioned recommendation.
- `tests/product-quality/Recommendation_Evaluation_Test.mjs` evaluates the policy against
  the committed dataset and rejects a candidate without guardrails or rollback metadata.
- Flutter telemetry and insight tests cover local consent, payload minimization,
  server recommendation and deterministic offline fallback.
