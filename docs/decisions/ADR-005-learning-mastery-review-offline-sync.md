# ADR-005 — Learning, mastery, review, and offline synchronization P0

- Status: Accepted
- Date: 2026-07-30
- Scope: Sprint E / Phase 7

## Context

The first learning slice already accepts append-only attempts, but it does not
separate a learning session from evidence derived from an attempt, does not
produce an explainable mastery state or review schedule, and does not provide a
server-owned reconciliation protocol for offline clients.

The P0 Android client must be able to retain a mutation locally, retry after an
unknown network outcome, and reconnect without creating duplicate learning
evidence or losing canonical progress. The backend remains a modular monolith;
P0 does not justify a broker, distributed cache, or last-write-wins state model.

## Decision

1. Keep `attempts` append-only. A learning session is a separate entity and an
   attempt may reference one session without becoming mutable session state.
2. Deduplicate a direct attempt by learner plus `clientAttemptId` or
   `Idempotency-Key`. Deduplicate an offline write independently by learner plus
   `clientMutationId`; reuse with different canonical data is a `409` conflict.
3. Accept only `attempt.submit` in sync contract version 1. A batch is
   transactional. A stale base cursor is rebased because attempts are
   append-only; it never overwrites accepted evidence.
4. Use an opaque, version-prefixed cursor over the learner-owned canonical
   change sequence. Pull is ordered, cursor-paginated, and carries `upsert` or
   `delete` operations. A revoked lesson completion is a tombstone.
5. Define lesson completion as at least one correct accepted attempt for every
   exercise in the exact currently published lesson version. Derive course
   completion when every current lesson is complete. Recalculate from canonical
   attempts whenever progress is read or an attempt is accepted.
6. Use mastery model version 1: each accepted concept evidence has weight `1`;
   mastery score is `correct evidence / total evidence`. Persist the counts,
   model version, and explanation inputs so the score is reproducible.
7. Use review model version 1 with a small SM-2-inspired schedule. Incorrect
   evidence is due immediately and resets repetitions. Correct intervals start
   at 1 day, then 3 days, then scale by an ease factor with a floor of `1.30`.
8. Inject `java.time.Clock` into scheduling and queue reads. Tests advance a
   mutable clock instead of sleeping or relying on wall time.
9. Publish in-process application events inside the same database transaction
   to connect learning, mastery, review, and sync modules. A listener failure
   rejects the transaction; no broker or eventual-consistency window is added
   for P0.
10. Include learning, mastery, review, and sync state in privacy deletion and
    guest-to-account merge participation.

## Consequences

- A retry after an unknown response returns the canonical attempt rather than
  creating new mastery evidence.
- The client can page from any accepted cursor and rebuild progress, mastery,
  review, session, and completion projections.
- Releasing a lesson version invalidates completion based only on older
  evidence; removing a completed lesson emits a deletion tombstone.
- Model changes require a new explicit model version and a recalculation plan;
  they cannot silently rewrite the meaning of stored evidence.
- Batch push is all-or-nothing in P0. Per-mutation partial acceptance can be
  introduced later only with a documented recovery contract.
- Cursor values are opaque ordering tokens, not authorization credentials.
  Every pull still scopes rows by the authenticated internal learner ID.

## Verification

- PostgreSQL migration creates sessions, completion projections, mastery
  evidence/state, review schedules, mutation reservations, and canonical change
  log.
- Integration tests cover offline push, retry replay, conflicting reuse,
  concurrent retry, pull pagination, mastery explanation inputs, clock-driven
  review availability, and canonical progress.
- Full Spring Modulith and API regression tests run against PostgreSQL
  Testcontainers.

## References

- [PostgreSQL `INSERT ... ON CONFLICT`](https://www.postgresql.org/docs/current/sql-insert.html#SQL-ON-CONFLICT)
- [Java `Clock`](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/time/Clock.html)
- [RFC 9110 — Idempotent methods](https://www.rfc-editor.org/rfc/rfc9110.html#name-idempotent-methods)
- [Flutter offline-first architecture](https://docs.flutter.dev/app-architecture/design-patterns/offline-first)
