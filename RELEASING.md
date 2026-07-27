# Releasing XPCCoding

This document is the release **mechanics** for XPCCoding: how a candidate becomes
a reviewed, annotated, immutable tag and a GitHub Release. It is intentionally
separate from — and subordinate to — two other documents:

- **The production-readiness audit**
  ([reference/PostRemediationProductionReadinessAudit.md](reference/PostRemediationProductionReadinessAudit.md))
  is the authoritative **GO / NO-GO gate**. Nothing here overrides it. The
  rehearsal in this document is *not* an audit and renders no GO decision.
- **The source API stability policy**
  ([reference/ApiStabilityPolicy.md](reference/ApiStabilityPolicy.md)) governs the
  Swift API surface and its diff gate.

Two compatibility axes stay separate throughout:

- **Source API** — see the stability policy above and `CHANGELOG.md`.
- **XPC object representation** — see [reference/WireFormat.md](reference/WireFormat.md).
  Because peers are co-built and co-deployed, a representation change carries **no**
  cross-release compatibility. Independently versioned peers, network transport,
  and persistence are out of scope. When the representation changes, the change
  updates the representation contract and the same-build fixtures, and **every
  participating application and XPC service must rebuild and redeploy together**.
  A representation change is therefore a coordinated-deployment event for the
  whole cohort, not a version-negotiated upgrade. It does not go through the
  source-API diff gate.

## Supported toolchain

Every release command and all release evidence run under the one supported
toolchain from [reference/SupportPolicy.md](reference/SupportPolicy.md): Xcode
26.6 (build 17F113), Apple Swift 6.3.3, on arm64. Select it explicitly:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

## Versioning

XPCCoding follows semantic versioning. It is currently **pre-1.0**; the
pre-hardening lightweight tags `0.0.1`/`0.0.2`/`0.0.3` are retained, immutable,
and are **not** a supported release line. See
[reference/ApiStabilityPolicy.md](reference/ApiStabilityPolicy.md) for the
pre-1.0 and 1.0 source-stability rules. The first supported-release candidate is
`0.1.0`. Generic commands below use `<version>` as a placeholder; for this
candidate it must resolve to `0.1.0`. Selecting a different first-release
version requires a reviewed repository change and a new audit candidate.

## Release process

### 1. Prepare the release branch

- Prepare the release branch; do not create the final tag yet.
- Use a pull request and satisfy the
  [main-branch protection policy](reference/MainBranchProtection.md). Do not
  weaken or bypass a required check to prepare or merge a release.
- Choose the proposed `<version>` and tag name `<version>` (bare semver, no `v`
  prefix — matching the existing `0.0.x` tags). The first supported candidate
  has already selected `0.1.0`; verify that value rather than deferring the
  choice until post-audit publication.

### 2. Update the changelog and, if needed, the API baseline

- Move the entries under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) to a
  new `## [<version>] - <date>` section, retain an empty **Unreleased** section,
  and update the compare links.
- If this release intentionally breaks the source API (permitted pre-1.0),
  first commit the reviewed source change, then advance the pin in
  `Scripts/api-baseline.env` to that existing commit and its tree hash in a
  subsequent commit in the same PR, per
  [reference/ApiStabilityPolicy.md](reference/ApiStabilityPolicy.md).

  A commit cannot contain its own not-yet-known SHA, so the baseline metadata
  commit necessarily follows the source commit it accepts. The pinned revision
  must contain the complete reviewed public API for the release; it need not be
  the final release-candidate commit when later commits change only
  documentation or release metadata.

### 3. Freeze the candidate

- Commit all release-preparation changes and confirm the working tree is clean.
- Record the final candidate commit SHA and tree hash.
- Confirm the candidate is reachable from the reviewed release branch/PR. Do
  not create the final tag yet.

### 4. Run the metadata and source API stability gates

Validate the committed Swift Package Index manifest against its pinned
official parser and the package's real identity, product, module, supported
configuration, documentation target, and repository URL:

```sh
bash Scripts/verify-swift-package-index-metadata.sh
```

See
[reference/SwiftPackageIndex.md](reference/SwiftPackageIndex.md) for the
configuration and service limitations.

```sh
bash Scripts/verify-api-stability.sh
```

This fails closed against the pinned baseline. See the stability policy for how
a deliberate break is recorded rather than merely allowed to pass.

### 5. Run the clean-clone release rehearsal

```sh
bash Scripts/release-rehearsal.sh <candidate-revision> <output-directory>
```

The rehearsal clones the committed candidate into a throwaway directory,
verifies the supported toolchain, runs the API gate and proportionate
build/test evidence, and captures the candidate metadata, a reproducible
source-archive SHA-256, and release-note inputs. **It publishes nothing** — no
tag, no GitHub Release, no Package Index submission — and it never touches the
existing lightweight tags. Keep its report with the release record.

The rehearsal validates mechanics; it is **not** a GO decision.

### 6. Pass the production-readiness audit

Run the audit in
[reference/PostRemediationProductionReadinessAudit.md](reference/PostRemediationProductionReadinessAudit.md)
against the candidate. A release proceeds only on a **GO** decision. A
`CONDITIONAL GO` or `NO-GO` blocks the release; remediate and re-run the affected
phases.

### 7. Record the release

Capture a release record (in the audit report and/or the GitHub Release body)
containing at least:

- **candidate SHA** and the resolved tree hash;
- **exact toolchain**: full `swift --version` and `xcodebuild -version` output,
  host architecture and OS version;
- **audit result and report**: the GO decision and a link to the dated audit
  report;
- **migrations**: the CHANGELOG **Removed**/**Changed** entries and any
  [migration guide](reference/MigrationGuide.md) updates for this version;
- **release notes**: the curated notes for the GitHub Release; and
- the **source-archive SHA-256** from the rehearsal. This is a rehearsal-internal
  reproducibility check on an uncompressed, unprefixed `git archive` tar; it does
  **not** match the gzipped, path-prefixed tarball GitHub generates for a
  release, so do not publish it as a checksum for that download.

### 8. Create the reviewed annotated, signed tag

Only after a GO decision. Tags are **annotated** and **preferably signed**, and
are **immutable** once pushed.

```sh
# Signed (preferred); requires a configured signing key:
git tag --sign <version> <candidate-sha> \
  --message "XPCCoding <version>"
git verify-tag <version>     # signature check; this FAILS on an unsigned tag

# If signing is unavailable, an annotated (unsigned) tag is the minimum.
# `git verify-tag` does not apply here — it reports "no signature found" —
# so confirm the tag is annotated rather than lightweight instead:
git tag --annotate <version> <candidate-sha> --message "XPCCoding <version>"
git cat-file -t refs/tags/<version>    # must print `tag`, not `commit`

git push origin <version>
```

Signing uses the committer's configured GPG or SSH signing key
(`git config user.signingkey`, `gpg.format`). Do not put signing material in the
repository.

**Immutability.** A published tag is never moved, re-pointed, or deleted. The
existing lightweight tags `0.0.1`/`0.0.2`/`0.0.3` are likewise never moved. A
mistake is corrected by a new higher version, not by rewriting a tag.

### 9. Create the GitHub Release

Create a GitHub Release tied to the annotated tag, with the curated release notes
from the release record. The Release is immutable in the same sense: corrections
ship as a new version.

```sh
gh release create <version> \
  --title "XPCCoding <version>" \
  --notes-file <release-notes.md> \
  --verify-tag
```

### 10. Post-release

The committed `.spi.yml` is verified before the audit. Swift Package Index
submission follows the audit's release-mechanics phase and the publication
ticket; it occurs only after the GO decision and the tag/Release exist. Nothing
is submitted speculatively before a GO.

## What a release must never do

- move, delete, or re-point any existing tag (lightweight or annotated);
- create a tag or GitHub Release before the audit reaches GO;
- publish from a dirty working tree or a shallow clone;
- ship a source-API break that is not recorded in `CHANGELOG.md` and reflected in
  the pinned API baseline; or
- treat a rehearsal as an audit.
