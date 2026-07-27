# XPCCoding Source API Stability Policy

This document governs one thing: the **Swift source API** the `XPCCoding`
library product vends. It is deliberately separate from two neighboring
contracts, and the three must not be conflated:

| Concern | Governed by | What it constrains |
| --- | --- | --- |
| Source API stability | this document | the public Swift symbols of `XPCCoding` |
| XPC object representation | [WireFormat.md](WireFormat.md) | the `xpc_object_t` trees produced/consumed |
| Toolchain / platform support | [SupportPolicy.md](SupportPolicy.md) | Xcode/Swift/OS build envelope |

A change can touch one axis without touching the others. Renaming a public method
is a source-API change with no representation change. Switching `Data` to a single
`XPC_TYPE_DATA` is a representation change (governed by `WireFormat.md` and its
fixtures) that may or may not move the source API. Keep them in separate review
lanes.

## Scope and intent

XPCCoding is a same-host IPC shim for a **co-built, co-deployed compilation
cohort** (see [WireFormat.md](WireFormat.md) and [SupportPolicy.md](SupportPolicy.md)).
Peers rebuild and redeploy together, so this policy is **not** an ABI or binary
compatibility promise, and it does not make independently versioned local peers
interoperate. Network transport, persistence, and cross-release representation
compatibility are also out of scope. Its purpose is narrower and still valuable:
to give the people who consume the source a **reviewed, documented,
intentional** API surface, and to make every change to that surface deliberate
rather than accidental.

The policy covers the **`XPCCoding` library product only**. The
`XPCCodingBenchmarks` executable is a development tool and is out of scope; the
gate excludes it.

## Versioning

XPCCoding follows [semantic versioning](https://semver.org).

### Pre-1.0 (current)

While the version is `0.y.z`, there is **no source-stability guarantee**: a
breaking change to the public API is permitted. The pre-hardening lightweight
tags `0.0.1`, `0.0.2`, and `0.0.3` predate the audited surface; they are retained
and immutable but are **not** a supported release line.

A permitted break is not a free break. Every intentional break must:

1. be recorded in [CHANGELOG.md](../CHANGELOG.md) under **Removed** or **Changed**
   with a migration;
2. update affected API documentation and, when a caller-facing recipe changes,
   the [migration guide](MigrationGuide.md); and
3. **advance the pinned API baseline** (`Scripts/api-baseline.env`) to an
   existing revision that includes the break, in the same reviewed PR.

Step 3 is what keeps the gate meaningful: the gate below fails on any break the
baseline does not yet include, so advancing the baseline is the explicit,
reviewed act of accepting a break. The source-changing commit comes first and a
subsequent metadata commit advances the pin to it; a commit cannot embed its own
not-yet-known SHA.

### 1.0 and later

At `1.0.0` the public API of the `XPCCoding` product becomes stable under
semver. After that:

- a breaking source change requires a **major** version bump;
- additive, source-compatible changes are minor bumps;
- fixes with no API change are patch bumps; and
- the pinned API baseline advances only together with a documented major release
  (or an additive minor that the gate already accepts).

The representation contract keeps its own, independent rule at every version:
because peers are co-built, a reviewed representation change does not get a format
version — it requires participating peers to rebuild and redeploy together and
updates [WireFormat.md](WireFormat.md) and the same-build fixtures. Source
versioning and representation versioning are not linked.

## The gate

`Scripts/verify-api-stability.sh` is the enforcement mechanism. It:

1. loads the pinned baseline from `Scripts/api-baseline.env`
   (`XPCCODING_BASELINE_REVISION`, `XPCCODING_BASELINE_TREE`,
   `XPCCODING_BASELINE_PRODUCT`);
2. confirms the revision still resolves to a commit and that its tree hash is
   unchanged, so a mistyped or rewritten pin fails loudly; and
3. runs, fail-closed,

   ```sh
   swift package diagnose-api-breaking-changes \
     "${XPCCODING_BASELINE_REVISION}" --products XPCCoding
   ```

The SwiftPM api-digester exits nonzero when it finds a break, so the script — and
CI — fail on any unrecorded public break. The baseline revision must be present
in the local object database, so CI checks out with `fetch-depth: 0`.

Run it locally from a checkout under the supported toolchain:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash Scripts/verify-api-stability.sh
```

`just release verify-api-stability` invokes the same script, and CI's
`Source API stability` job runs it after verifying the support policy.

### The pinned baseline

The baseline is a **commit SHA plus its tree hash**, not a released tag, because
the audited hardened surface is a commit (`5f6480ec450eb6a1067d183d62d47476f2ca5b4b`),
and the old lightweight tags are pre-hardening. Storing the tree hash lets the
verify script detect a repointed or rewritten baseline.

To advance the baseline (only when deliberately shipping a break, per the
pre-1.0 rule above), first commit the reviewed source change. In a subsequent
commit in the same PR, set both fields in `Scripts/api-baseline.env` to that
source revision and its `git rev-parse <rev>^{tree}` value, alongside the
CHANGELOG and migration updates. The pin must represent the complete intended
public API, even if documentation-only commits follow it before the final release
candidate.

## Regression evidence against `0.0.3`

The intentional hardening breaks relative to the pre-hardening tag reproduce with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift package diagnose-api-breaking-changes 0.0.3 --products XPCCoding
```

This exits `1` and, under the supported Swift 6.3.3 toolchain, reports four
removals: the two `XPCDecoder` initializers and the
`XPCCodec.encoder` / `XPCCodec.decoder` properties.
[CHANGELOG.md](../CHANGELOG.md) enumerates those results and also retains the
manually identified
`KeyedEncodingContainer.efficientlyEncodeBinaryData(_:forKey:)` overload rename
as a migration because the current diagnosis does not report that
extension-method source change. Run the command when cutting a release and
reconcile its actual output against the four tool-reported removals; a
discrepancy is a documentation defect to fix before tagging.

## Negative control (proving the gate fails)

The gate is only credible if it actually fails on a break. To demonstrate this
**without mutating the release branch**, do it in a disposable worktree:

```sh
git worktree add /tmp/xpc-gate-negcontrol HEAD
cd /tmp/xpc-gate-negcontrol
# Hide or remove a public symbol, e.g. change `public func makeEncoder()` to
# `internal func makeEncoder()` in Sources/XPCCoding/XPCCodec.swift.
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash Scripts/verify-api-stability.sh   # expected: reports the break, exits 1
cd -
git worktree remove --force /tmp/xpc-gate-negcontrol
```

Never leave that mutation in the branch; the worktree is discarded after the gate
is observed failing.
