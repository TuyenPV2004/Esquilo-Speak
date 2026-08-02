# Product quality metrics catalog

- Catalog version: `product-quality-metrics-v1`
- Dashboard schema: `product-quality-dashboard-v1`
- Time zone: UTC
- Default course: `course-en-for-vi`
- Optional telemetry retention: 30 days

Every rate is reported with numerator, denominator, source and sample size. `null`
means the denominator is zero; it must not be rendered as 0%. Canonical evidence is
available independently of analytics consent. `consented_telemetry` covers only the
opted-in sample and must carry the dashboard sampling note.

Backend queries consume the versioned, read-only `product_quality_*` reporting views.
The source names below identify the owning canonical domain; the analytics module does
not write those records or query their internal table names from application code.

| Metric code | Definition | Source | Interpretation boundary |
| --- | --- | --- | --- |
| `weekly_evidence_learner` | Distinct learners in the trailing 7 UTC dates with an explicit completed learning/lesson/daily session backed by an accepted attempt, mastery or completion record. | `learning_sessions`, `learning_completions`, evidence-backed `engagement_events` | North-star count, not total app opens. A lifecycle event without accepted learning evidence is excluded. |
| `first_lesson_completion` | Learners with active completion for course lesson position 1 / learners with an accepted attempt in that lesson during the window. | `attempts`, `learning_completions`, `lessons` | Initial target is at least 60%; rebaseline only after 30 days of representative closed-test data. |
| `unit_one_completion` | Learners completing every lesson in the versioned first unit / learners who started a lesson in that same unit during the window. | `learning_completions`, versioned `lessons.unit_id`, `attempts` | The first unit is resolved by course lesson order; no unit ID is hardcoded in the metric query. |
| `d1_retention` | Learners with accepted learning evidence exactly one UTC date after their first course evidence / learners whose first course evidence date is in the cohort window and has matured by one day. | `attempts` | Immature dates are excluded from the denominator automatically. |
| `d7_retention` | Learners with accepted learning evidence exactly seven UTC dates after their first course evidence / learners whose first course evidence date is in the cohort window and has matured by seven days. | `attempts` | Immature dates are excluded; target remains unset until closed beta. |
| `review_completion` | `review_completed` / `review_started` events in the window. | `analytics_events` | Consented sample only; never infer non-consenting learners abandoned. |
| `attempt_correctness` | Correct accepted attempts / all accepted attempts. | `attempts` | Segment by lesson/exercise only after the minimum anomaly sample. |
| `attempt_retry_usage` | Attempts with `evidence.retryIndex > 0` / all accepted attempts. | `attempts.evidence` | Retry is a diagnostic signal, not automatically failure. |
| `attempt_hint_usage` | Attempts with `evidence.hintUsed=true` / all accepted attempts. | `attempts.evidence` | High use can reflect appropriate scaffolding; review with correctness and reports. |
| `attempt_response_time_ms` | Mean non-negative accepted `response_time_ms`; dashboard includes sample size. | `attempts` | Client telemetry sends only buckets; canonical attempts retain the operational value already required for learning evidence. Do not rank learners by speed. |
| `content_report_rate` | Content-report tickets / accepted attempts in the course window. | `support_tickets`, `attempts` | Free-form report text remains in support, never analytics. Serious reports require an owner regardless of rate. |
| drop-off group | Count of `lesson_abandoned`, `review_abandoned` or `practice_abandoned`, grouped by lesson and exercise type where present. | `analytics_events` | Consented sample only; the queue retains traceable content refs, not raw responses. |

## Content-quality queue policy V1

- `content_report`: one or more open/triaged reports creates a medium-priority item;
  three or more reports raise it to high.
- `difficulty_anomaly`: at least 5 accepted attempts and correctness below 60%; below
  35% is high priority. The small threshold is for closed-test discovery, not an
  automatic content verdict.
- `feedback_usefulness`: at least 5 opted-in usefulness responses and helpfulness below
  60% creates a medium-priority item.
- Product/content staff must inspect the item, source sample and canonical exercise
  before resolving or dismissing it. A rate never edits or retires content automatically.

## Dashboard query

`GET /api/operations/v1/product-quality/dashboard?courseId=course-en-for-vi&from=YYYY-MM-DD&to=YYYY-MM-DD`

The operations token requires `SCOPE_operations` and role `SUPPORT` or `ADMIN`.
The content queue is available at
`GET /api/operations/v1/content-quality/queue?courseId=course-en-for-vi`.
