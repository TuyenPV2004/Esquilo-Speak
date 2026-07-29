# Contract compatibility gate

JSON Schema files are parsed and the OpenAPI document is linted on every CI
run. Pull requests additionally compare
`contracts/openapi/esquilospeak-learning-v1.yaml` with the target branch using
oasdiff.

The compatibility job fails on warning-level or error-level breaking changes.
The comparison remains inside the CI runner (`review: false`).

An intentional breaking change requires a new API major version and an accepted
decision record; it must not be hidden with an ignore rule.
