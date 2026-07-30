# Contract compatibility gate

JSON Schema files are parsed and the OpenAPI document is linted on every CI
run. Pull requests additionally compare
`contracts/openapi/esquilospeak-learning-v1.yaml` with the target branch using
oasdiff.

The compatibility job fails on warning-level or error-level breaking changes.
The comparison remains inside the CI runner (`review: false`).

An intentional breaking change requires a new API major version and an accepted
decision record; it must not be hidden with an ignore rule.

The pull request that first introduces this gate uses the accepted P0 `0.4.0`
release artifact as its baseline because the target branch predates the gate.
Once the gate is present on the target branch, CI always compares against that
branch's active OpenAPI document. No breaking-change check is ignored.

## P0 Android integration freeze

`P0_Release_Freeze_Manifest.json` pins the OpenAPI version and SHA-256 together
with the immutable, version-named release artifact under `contracts/openapi/`
and every JSON fixture under `fixtures/`. The active OpenAPI document can
therefore advance without mutating the P0 release evidence. The validator also
requires the fixture bundle to cover every `/api/mobile/v1/**` operation in the
frozen artifact, rejects token/password/private-key fields, and ensures learner
lesson delivery contains no answer or explanation.

Run the local release-freeze check from the repository root:

```powershell
node .\tests\contract\Validate_P0_Release_Freeze.mjs
```

Do not update a checksum merely to make CI pass. A contract or fixture change
must first pass Redocly lint, oasdiff compatibility review, backend regression
and the affected Android tests. An intentional breaking change still requires
a new API major version and accepted decision record.
