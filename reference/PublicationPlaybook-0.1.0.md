# XPCCoding 0.1.0 Review and Publication Playbook

This is the maintainer-facing playbook for the frozen `0.1.0` candidate. It
separates code review from publication so that reviewing or validating the
candidate cannot accidentally publish it.

## Frozen release identity

| Item | Value |
| --- | --- |
| Version and tag | `0.1.0` |
| Audited source commit | `8dab29a230817c3911a2a8e48467c49a9c0a2604` |
| Audited source tree | `0c2c6353840e7c546ed18656b38f548f8c5b0d54` |
| Audit result | `GO`, 2026-07-29 |
| Maintainer audit decision | `GO` approved, 2026-07-29 |
| Publication authorization | Audit-report PR only, 2026-08-05 |
| Audit report | [ProductionReadinessAudit-2026-07-29.md](ProductionReadinessAudit-2026-07-29.md) |
| General release policy | [RELEASING.md](../RELEASING.md) |
| Release ticket | [GitHub issue #51](https://github.com/plx/hdxl-xpc-coding/issues/51) |

The approved branch-protection policy consists of the exact 15 required
supported-configuration checks recorded in
[MainBranchProtection.md](MainBranchProtection.md). The three advisory jobs
named there remain visible but are not required checks. This playbook does not
change that decision.

## Authority boundary

Until the maintainer gives the explicit authorization in
[Publication authorization](#publication-authorization), only local and
read-only remote actions are permitted. In particular, do **not**:

- push a branch or tag;
- open, ready, or merge a pull request;
- create or edit a GitHub Release;
- submit the repository to Swift Package Index; or
- close issues #51, #52, or #59.

If any source, package configuration, release metadata, CI configuration, or
other candidate file needs to change, stop. The changed tree is a new release
candidate and must receive an appropriately scoped audit before publication.
The audit report and this playbook may be merged after the audit because the
release tag still points to the exact audited source commit above.

## Part A: Maintainer code review

### 1. Establish the exact review target

Use a clean clone or preserve unrelated local files. Workspace-local files such
as `.vscode/` are not part of the candidate and must remain untouched.

```sh
git fetch origin --prune

candidate=8dab29a230817c3911a2a8e48467c49a9c0a2604
expected_tree=0c2c6353840e7c546ed18656b38f548f8c5b0d54

test "$(git rev-parse "$candidate^{commit}")" = "$candidate"
test "$(git rev-parse "$candidate^{tree}")" = "$expected_tree"
test "$(git rev-parse origin/main^{commit})" = "$candidate"

git show --stat --summary "$candidate"
git log --first-parent --oneline 0.0.3.."$candidate"
git diff --stat 0.0.3.."$candidate"
```

If `origin/main` has advanced only because the dated audit report was merged,
replace the third assertion with this ancestry check:

```sh
git merge-base --is-ancestor "$candidate" origin/main
```

In either case, the release tag target and tree must remain the two frozen
values above.

### 2. Review the public contract

Review the package identity, public facades, configuration ownership, source
migrations, and compatibility claims together:

- [Package.swift](../Package.swift)
- [XPCCodec.swift](../Sources/XPCCoding/XPCCodec.swift)
- [XPCCodec+Configuration.swift](../Sources/XPCCoding/XPCCodec+Configuration.swift)
- [XPCEncoder.swift](../Sources/XPCCoding/Encoding/XPCEncoder.swift)
- [XPCDecoder.swift](../Sources/XPCCoding/Decoding/XPCDecoder.swift)
- [XPCDecoder+ResourceLimits.swift](../Sources/XPCCoding/Decoding/XPCDecoder+ResourceLimits.swift)
- [CHANGELOG.md](../CHANGELOG.md)
- [MigrationGuide.md](MigrationGuide.md)
- [ApiStabilityPolicy.md](ApiStabilityPolicy.md)

```sh
git diff 0.0.3.."$candidate" -- \
  Package.swift \
  Sources/XPCCoding/XPCCodec.swift \
  Sources/XPCCoding/XPCCodec+Configuration.swift \
  Sources/XPCCoding/Encoding/XPCEncoder.swift \
  Sources/XPCCoding/Decoding/XPCDecoder.swift \
  Sources/XPCCoding/Decoding/XPCDecoder+ResourceLimits.swift \
  CHANGELOG.md \
  reference/MigrationGuide.md \
  reference/ApiStabilityPolicy.md \
  Scripts/api-baseline.env
```

Review questions:

- Do the facade and codec APIs make ownership and reuse behavior clear?
- Are every intentional source break and its migration recorded?
- Does the API baseline identify the reviewed hardened surface?
- Are Swift 6.3, arm64, Apple 26+, and SwiftPM claims exact rather than broad?

### 3. Review representation and value handling

Read the representation contract before the implementation:

- [WireFormat.md](WireFormat.md)
- [EmbeddedNullByteHandling.md](EmbeddedNullByteHandling.md)
- [string extraction](../Sources/XPCCoding/Decoding/Details/xpc_object_t+Extraction.swift)
- [string construction](../Sources/XPCCoding/Encoding/Details/String+xpc_object_t.swift)
- [binary-data representation](../Sources/XPCCoding/Protocols/XPCBinaryDataRepresentationConvertible.swift)
- [conversion protocols](../Sources/XPCCoding/Protocols/LosslessXPCObjectConvertible.swift)

```sh
git diff 0.0.3.."$candidate" -- \
  reference/WireFormat.md \
  reference/EmbeddedNullByteHandling.md \
  Sources/XPCCoding/Protocols \
  Sources/XPCCoding/Support \
  Sources/XPCCoding/Encoding/Details/String+xpc_object_t.swift \
  Sources/XPCCoding/Decoding/Details/xpc_object_t+Extraction.swift \
  Tests/XPCCodingTests/Fixtures \
  Tests/XPCCodingTests/Suites/DataRepresentationTests.swift \
  Tests/XPCCodingTests/Suites/NumericRepresentationTests.swift \
  Tests/XPCCodingTests/Suites/PercentEscapeRegressionTests.swift \
  Tests/XPCCodingTests/Suites/StrictUTF8DecodingTests.swift
```

Review questions:

- Is every documented representation matched by fixtures and round trips?
- Are text keys and values reversible, including embedded zero bytes?
- Are malformed text, numeric widths, byte counts, and data sizes rejected
  deterministically?
- Is the same-build/co-deployment boundary stated consistently?

### 4. Review encoder/decoder semantics and bounds

Review the internal encoders, decoders, containers, coding paths, reference
state, `userInfo`, and finite decode limits:

```sh
git diff 0.0.3.."$candidate" -- \
  Sources/XPCCoding/Encoding \
  Sources/XPCCoding/Decoding \
  Tests/XPCCodingTests/Suites/ConcurrencyTests.swift \
  Tests/XPCCodingTests/Suites/DecodingCodingPathTests.swift \
  Tests/XPCCodingTests/Suites/FacadeAndStateCoverageTests.swift \
  Tests/XPCCodingTests/Suites/InheritanceTests.swift \
  Tests/XPCCodingTests/Suites/KeyedContainerCoverageTests.swift \
  Tests/XPCCodingTests/Suites/KeyedDecodeNilTests.swift \
  Tests/XPCCodingTests/Suites/SupportAndErrorCoverageTests.swift
```

Review questions:

- Do nested and referencing containers update the intended parent slot?
- Are coding paths, missing values, type mismatches, and corrupted data
  classified consistently?
- Does `userInfo` propagate through nested and referencing operations?
- Are depth, element, node, text, and data budgets finite and applied once per
  top-level operation?
- Are immutable facade values usable concurrently while mutable encoder and
  decoder instances remain isolated?

### 5. Review transport and independent-client evidence

Review the public-client and real same-host request/reply packages:

- [PublicAPIConsumer](../IntegrationTests/PublicAPIConsumer)
- [XPCProcessBoundary](../IntegrationTests/XPCProcessBoundary)
- [BaselineProbe](../IntegrationTests/BaselineProbe)
- [audit evidence](audit-evidence/2026-07-29/README.md)

The dated audit report already records the deeper bounded-input, value-lifetime,
concurrency, regression, resource-growth, and performance checks. A maintainer
may sample that retained evidence without rerunning every lower-level
instrumented command during code review.

### 6. Review repository and release controls

```sh
git diff 0.0.3.."$candidate" -- \
  .github \
  .spi.yml \
  Scripts \
  Tools \
  README.md \
  CONTRIBUTING.md \
  SECURITY.md \
  LICENSE \
  THIRD_PARTY_NOTICES.md \
  RELEASING.md \
  reference/ContinuousIntegration.md \
  reference/MainBranchProtection.md \
  reference/RepositorySecurity.md \
  reference/SupportPolicy.md \
  reference/SwiftPackageIndex.md \
  reference/UpstreamProvenance.md
```

Confirm:

- the checked-in and live `main` rulesets agree;
- exactly the approved 15 checks are required;
- the three explicitly advisory jobs are not promoted to requirements;
- provenance and licensing cover the retained upstream material;
- release notes, changelog, migration guidance, README, and support policy agree;
- `.spi.yml` names the canonical package, product, module, repository, and
  supported service configurations.

### 7. Run non-publishing validation

These commands do not publish anything. Run them from the exact candidate in a
clean checkout using the supported toolchain:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

swift --version
xcodebuild -version
uname -m
sw_vers

bash Scripts/verify-support-policy.sh
swift package dump-package >/dev/null
bash Scripts/verify-public-api.sh
bash Scripts/verify-api-stability.sh
bash Scripts/verify-swift-package-index-metadata.sh
bash Scripts/check-swift-format.sh
just lint check-all github-actions-logging
just docs check-all github-actions-logging
just test debug
just test release
bash Scripts/run-xpc-integration.sh
bash Scripts/verify-main-ruleset.sh
```

For a final clean-clone rehearsal, use a new temporary directory:

```sh
rehearsal_dir="$(mktemp -d)"
bash Scripts/release-rehearsal.sh "$candidate" "$rehearsal_dir"
```

The rehearsal is read-only with respect to the canonical repository and
publishes nothing.

### 8. Record the review decision

Before authorizing publication, confirm all of the following:

- [ ] I reviewed the exact candidate commit and tree above.
- [ ] I reviewed the public API and all recorded migrations.
- [ ] I reviewed representation, decoding limits, and same-build deployment
  constraints.
- [ ] I reviewed the implementation and representative unit/integration tests.
- [ ] I reviewed the dated audit report and sampled evidence as appropriate.
- [ ] I reviewed repository, licensing, CI, and release controls.
- [ ] I accept the support envelope and the `0.1.0` release notes.
- [ ] No candidate change is required.

If any item is not satisfied, do not authorize publication. Record the concern,
make a new candidate if necessary, and rerun the audit portions invalidated by
the change.

## Publication authorization

After completing the review, the maintainer can authorize the complete sequence
with this exact or equivalently explicit statement:

> I have completed my code review. I authorize publication of XPCCoding 0.1.0
> from audited source commit
> `8dab29a230817c3911a2a8e48467c49a9c0a2604` (tree
> `0c2c6353840e7c546ed18656b38f548f8c5b0d54`). I authorize the audit-report
> pull request and normal merge closing #52; creation and push of immutable
> annotated tag `0.1.0` at that exact commit; creation of the GitHub Release
> from the approved #106 notes; submission of
> `https://github.com/plx/hdxl-xpc-coding.git` to Swift Package Index; final
> artifact verification; and closure of #51 and #59 when their acceptance
> criteria are met. Use exactly the approved 15 protected checks. The three
> advisory jobs remain non-required.

Authorization may instead be granted one stage at a time. Silence, audit-GO
approval, code-review progress, or approval of the playbook is not publication
authorization.

## Part B: Authorized publication sequence

Do not begin this part until the maintainer gives the authorization above.

### 1. Publish the audit report through pull request #52

1. Add the publication-authorization date to the audit report without changing
   the audited source identity.
2. Rebase or merge the latest `origin/main` into the report branch as needed.
3. Run documentation link checks, Markdown checks, `git diff --check`, and the
   repository's applicable local gates.
4. Push only the audit-report branch.
5. Open one draft pull request titled
   `[P1] Record the 0.1.0 production-readiness GO audit`, with `Closes #52` in
   its body and links to the candidate, report, and evidence.
6. Confirm that the pull request changes only the dated report, retained audit
   evidence, and this playbook/release-document link.
7. Wait for the exact 15 required checks. Resolve every review thread, bring
   the branch up to date, and wait again if the head changes.
8. Mark the pull request ready and merge it with a normal merge commit. Do not
   squash or rebase merge. Delete the remote report branch.
9. Confirm #52 closed with the recorded `GO`.

The merge commit becomes newer than the candidate on `main`; it is not the tag
target. Verify the frozen candidate remains an ancestor and its tree is
unchanged.

### 2. Perform the final publication preflight

Use a clean checkout and re-establish every identity:

```sh
git fetch origin --prune --tags

candidate=8dab29a230817c3911a2a8e48467c49a9c0a2604
expected_tree=0c2c6353840e7c546ed18656b38f548f8c5b0d54
release_version=0.1.0

test "$(git rev-parse "$candidate^{commit}")" = "$candidate"
test "$(git rev-parse "$candidate^{tree}")" = "$expected_tree"
git merge-base --is-ancestor "$candidate" origin/main

test -z "$(git tag --list "$release_version")"
test -z "$(git ls-remote --tags origin "refs/tags/$release_version")"
test -z "$(gh release list --repo plx/hdxl-xpc-coding \
  --limit 100 --json tagName \
  --jq '.[] | select(.tagName == "0.1.0") | .tagName')"

bash Scripts/verify-main-ruleset.sh
git config --get user.signingkey || true
git config --get gpg.format || true
```

A missing signing configuration does not authorize a policy change. Prefer a
signed tag; if signing cannot be made available, record the reason and use the
documented minimum of an unsigned annotated tag. Stop if the version already
exists anywhere or if any identity assertion fails.

### 3. Create and publish the immutable tag

Signed, preferred path:

```sh
git tag --sign "$release_version" "$candidate" \
  --message "XPCCoding $release_version"
git verify-tag "$release_version"
```

Unsigned annotated fallback:

```sh
git tag --annotate "$release_version" "$candidate" \
  --message "XPCCoding $release_version"
git cat-file -t "refs/tags/$release_version"
```

Before any push, both paths must pass:

```sh
test "$(git cat-file -t "refs/tags/$release_version")" = tag
test "$(git rev-parse "$release_version^{commit}")" = "$candidate"
test "$(git rev-parse "$release_version^{tree}")" = "$expected_tree"
git show --no-patch --decorate "$release_version"
```

Then publish the tag and verify its remote target:

```sh
git push origin "refs/tags/$release_version"
git ls-remote --tags origin \
  "refs/tags/$release_version" \
  "refs/tags/$release_version^{}"
```

For an annotated tag, the `^{}` line must identify the candidate commit. Once
pushed, the tag is immutable: never delete, replace, or move it.

### 4. Create and verify the GitHub Release

The approved notes are the `### XPCCoding 0.1.0` subsection of
[issue #106 comment 5096333190](https://github.com/plx/hdxl-xpc-coding/issues/106#issuecomment-5096333190).
Fetch them into a temporary directory, extract only that subsection, and review
the resulting file before publication:

```sh
release_workdir="$(mktemp -d)"
gh api repos/plx/hdxl-xpc-coding/issues/comments/5096333190 \
  --jq .body >"$release_workdir/issue-106-comment.md"

awk '
  /^### XPCCoding 0.1.0$/ { copying = 1 }
  /^These notes are proposed inputs/ { copying = 0 }
  copying
' "$release_workdir/issue-106-comment.md" \
  >"$release_workdir/release-notes-0.1.0.md"

sed -n '1,240p' "$release_workdir/release-notes-0.1.0.md"
```

Confirm the file begins with `### XPCCoding 0.1.0`, ends with the references to
the changelog and contract documents, contains no issue-comment preamble, and
matches the maintainer-approved text. Then:

```sh
gh release create "$release_version" \
  --repo plx/hdxl-xpc-coding \
  --title "XPCCoding $release_version" \
  --notes-file "$release_workdir/release-notes-0.1.0.md" \
  --verify-tag

gh release view "$release_version" \
  --repo plx/hdxl-xpc-coding \
  --json name,tagName,targetCommitish,isDraft,isPrerelease,publishedAt,url,body
```

Verify the release is public, non-draft, non-prerelease, names `0.1.0`, and
contains the approved support, migration, representation, and audit statements.

### 5. Submit to Swift Package Index

As verified on 2026-07-29, the official submission page is
[Add a Package](https://swiftpackageindex.com/add-a-package). The service
requires a public repository, a root `Package.swift`, valid
`swift package dump-package` output, a successful build, and a clone URL that
includes both `https` and `.git`; it says packages should have at least one
semantic-version release tag. This candidate meets that recommendation before
submission.

Only after the tag and GitHub Release exist:

1. Open the official submission page.
2. Submit exactly
   `https://github.com/plx/hdxl-xpc-coding.git`.
3. Record the resulting confirmation, issue, pull request, or package URL.
4. Do not modify the repository or add a badge during this release ticket.
5. Wait for the package page and `0.1.0` release to appear.
6. Inspect the service's build matrix and generated API documentation. Record
   unsupported service cells as service limitations; do not broaden this
   package's support claim.

The service polls indexed repositories periodically. Once accepted, later
release discovery does not require resubmitting the package.

### 6. Verify every public artifact

From a fresh temporary clone:

```sh
verification_dir="$(mktemp -d)"
git clone https://github.com/plx/hdxl-xpc-coding.git \
  "$verification_dir/hdxl-xpc-coding"
git -C "$verification_dir/hdxl-xpc-coding" checkout 0.1.0

test "$(
  git -C "$verification_dir/hdxl-xpc-coding" rev-parse HEAD
)" = "$candidate"
test "$(
  git -C "$verification_dir/hdxl-xpc-coding" rev-parse HEAD^{tree}
)" = "$expected_tree"
test "$(
  git -C "$verification_dir/hdxl-xpc-coding" cat-file -t refs/tags/0.1.0
)" = tag

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift package \
  --package-path "$verification_dir/hdxl-xpc-coding" \
  dump-package >/dev/null
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test \
  --package-path "$verification_dir/hdxl-xpc-coding" \
  -Xswiftc -warnings-as-errors
```

If signed, also run:

```sh
git -C "$verification_dir/hdxl-xpc-coding" verify-tag 0.1.0
```

Finally verify:

- [ ] remote tag `0.1.0` dereferences to the exact candidate;
- [ ] GitHub Release `0.1.0` is public and uses the approved notes;
- [ ] tags `0.0.1`, `0.0.2`, and `0.0.3` are unchanged;
- [ ] the Swift Package Index entry resolves to this repository and release;
- [ ] available Package Index build and documentation results were inspected;
- [ ] every public artifact retains the Swift 6.3/Apple 26+/arm64 support
  envelope and same-build representation boundary.

### 7. Close the release program

Add the immutable tag, GitHub Release, Package Index listing, build results,
documentation, and verification links to issue #51. Close #51 only when every
acceptance criterion is satisfied.

After #51 closes, confirm all native children of #59 are closed and add a final
summary with links to #52, #51, the audit report, tag, Release, and Package
Index entry. Close #59 only when its program-level gates are all satisfied.

## Stop and recovery rules

- Before a tag push, stop on any mismatch. An unpublished local tag may be
  removed and recreated only after confirming it was never pushed.
- After a tag push, never move, replace, reuse, or delete the tag.
- If the release notes or Package Index submission fail after tag publication,
  leave the tag intact, diagnose the external failure, and retry only the
  failed external step when safe.
- If source or metadata must change after publication, make a new patch
  release and run the release/audit gates required for that new candidate.
- Never weaken branch protection, bypass a required check, broaden support
  claims, or edit the audited candidate to make publication succeed.
