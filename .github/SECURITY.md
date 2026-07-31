# Security and dependency review policy

## Reporting

Do not open a public issue for a suspected vulnerability. Use GitHub private
vulnerability reporting when it is enabled, or contact the repository owner
through a private channel.

Do not include credentials, tokens, personal data, voice recordings, or
production configuration in a report.

## Dependency review

Dependabot version-update pull requests are intentionally disabled. The project
uses the following manual review cadence instead:

- Review GitHub Dependabot alerts and security advisories at least every two
  weeks and before each release candidate.
- Review direct Gradle and Flutter dependencies once per month.
- Apply critical or actively exploited fixes immediately.
- Triage high-severity findings within two business days.
- Record deferred findings with an owner, rationale, compensating control, and
  review date.
- Do not combine unrelated dependency upgrades with feature work.

For each dependency change, run the backend regression suite, Flutter analyze
and tests, Android build, contract validation, and the end-to-end journey when
the dependency can affect runtime behavior.

## Repository settings required before release

The repository owner must verify that secret scanning, push protection,
Dependabot alerts, branch protection, and required CI checks are enabled.
Repository settings are external state and cannot be guaranteed by files in
this repository.
