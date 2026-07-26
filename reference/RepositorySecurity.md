# Repository Security Controls

[`SECURITY.md`](../SECURITY.md) is the normative reporting and supported-
version policy. This document records the repository controls that support it
and the commands maintainers use to verify them.

## Enabled controls

The repository is public and owned by an individual account. The following
controls were enabled and API-verified on 2026-07-26:

<!-- markdownlint-disable MD013 -->

| Control | Configuration |
| --- | --- |
| Private vulnerability reporting | Enabled; reports enter a private repository security advisory |
| Dependency graph and Dependabot alerts | Enabled |
| Dependabot security updates | Enabled |
| Dependabot version updates | Weekly checks for pinned GitHub Actions through [`.github/dependabot.yml`](../.github/dependabot.yml) |
| Secret scanning | Enabled for the repository |
| Push protection | Enabled for supported provider patterns |
| CodeQL advanced setup | Extended Swift and Actions queries; Swift uses a manual Xcode 26.6 iOS build; weekly schedule |
| Actions token permissions | Read-only by default; workflows cannot approve pull requests |
| Action pinning | Repository policy requires full-length commit SHAs |
| Independent history scan | Pinned Gitleaks 8.30.1 binary and SHA-256, every reachable commit, no baseline or allowlist |

<!-- markdownlint-enable MD013 -->

The independent history scan runs for pull requests, pushes to `main`, release
tags matching `v*`, a weekly schedule, and manual dispatch. It checks out full
history and explicitly passes `--log-opts=--all`; a shallow or current-tree-only
scan is not accepted. The scanner redacts detected values from its output.

## Deliberate limitations

GitHub currently leaves generic non-provider secret patterns and secret
validity checks disabled for this public, user-owned repository even when
their repository settings are requested through the API. Those controls are
not claimed. The pinned Gitleaks scan supplies an additional generic-pattern
control, but it does not make a leaked credential safe or prove validity.

Notification delivery for private reports depends on the maintainer's GitHub
notification settings and is not asserted by the repository.

GitHub's default Swift autobuild used `/usr/bin/swift`, outside the supported
Xcode 26.6 toolchain, and failed against the package's macOS 26 API surface.
GitHub then removed Swift from default setup. A manually traced SwiftPM macOS
build exhibited the same CodeQL extractor mismatch around `Float16`.

The repository therefore uses advanced setup in
[`.github/workflows/codeql.yml`](../.github/workflows/codeql.yml): Actions
analysis uses the build-free mode, while Swift analysis selects Xcode 26.6 and
manually builds the library for its supported iOS 26 target. Default setup is
deliberately disabled so the two configurations do not conflict. Completed
analyses, rather than the presence of a settings toggle, are the evidence that
scanning works.

GitHub's secret-scanning history-progress endpoint reports that Advanced
Security is unavailable even though public-repository secret scanning is
enabled. This repository therefore does not claim API-visible progress for the
GitHub-managed history scan; the independent Gitleaks job supplies explicit
whole-history evidence.

## API verification

Run these read-only checks with an authenticated `gh` session that has
repository administration and security-event access:

```sh
gh api repos/plx/hdxl-xpc-coding \
  --jq '{visibility, security_and_analysis}'

gh api repos/plx/hdxl-xpc-coding/private-vulnerability-reporting
gh api repos/plx/hdxl-xpc-coding/automated-security-fixes
gh api repos/plx/hdxl-xpc-coding/actions/permissions
gh api repos/plx/hdxl-xpc-coding/actions/permissions/workflow
gh api repos/plx/hdxl-xpc-coding/code-scanning/default-setup
```

The final command should report `not-configured`; CodeQL is intentionally
configured through the pinned repository workflow instead.

The vulnerability-alert endpoint returns HTTP 204 when enabled:

```sh
gh api --include \
  repos/plx/hdxl-xpc-coding/vulnerability-alerts
```

Open alerts and completed analyses are separate evidence:

```sh
gh api 'repos/plx/hdxl-xpc-coding/dependabot/alerts?state=open'
gh api 'repos/plx/hdxl-xpc-coding/secret-scanning/alerts?state=open'
gh api 'repos/plx/hdxl-xpc-coding/code-scanning/alerts?state=open'
gh api repos/plx/hdxl-xpc-coding/code-scanning/analyses
```

Do not paste authentication headers, credentials, or unredacted alert contents
into issues or pull requests.

## Safe negative control

Validate the pinned scanner in a disposable local Git repository, never by
committing a credential-shaped fixture to this repository. A high-entropy,
clearly synthetic value assigned to an `api_key` field must produce a redacted
`generic-api-key` finding and exit status 1. Delete the disposable repository
after recording the scanner version, exit status, rule identifier, and
redacted result.
