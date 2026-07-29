# Version-controlled project decisions

This directory is the durable source of truth for accepted architecture and
delivery decisions.

Research notes and working documents may remain local, but any decision that
changes a public contract, security/privacy behavior, module boundary, release
gate, or foundational dependency must be recorded here before implementation.

Decision status:

- `Proposed`: under review and must not be treated as committed scope.
- `Accepted`: approved and governing implementation.
- `Superseded`: replaced by a newer decision that links back to it.
- `Rejected`: considered but intentionally not adopted.

## Accepted decisions

- [`ADR-002`](ADR-002-foundation-and-first-learning-slice.md): foundation and
  first learning slice.
- [`ADR-003`](ADR-003-first-slice-closure-and-p0-gate.md): first-slice closure
  and the requirement to accept the P0 gate before identity expansion.
- [`ADR-004`](ADR-004-p0-product-privacy-and-service-decisions.md): accepted P0
  product, age, guest, consent, retention, service, and support decisions.
