# Regression-First Baseline Evidence

This macOS-only probe demonstrates that the historical defects the
production-readiness audit found are really present at the revision it audited,
`813c52e`, and really absent from the working tree.

A test suite that only asserts today's behavior cannot show that it ever caught
anything. This probe closes that gap by running one experiment against two
libraries and requiring a *different* answer from each.

It is not a compatibility, interoperability, or migration test. It builds an
extracted copy of an old revision purely so its defects can be observed; nothing
here suggests that two revisions of XPCCoding are meant to interoperate, and
nothing here becomes a supported API.

## Run

From the repository root, with the
[supported Xcode toolchain](../../reference/SupportPolicy.md) selected:

```sh
bash Scripts/run-baseline-evidence.sh
```

The script:

- builds the probe against the working tree and requires every defect to be
  absent;
- resolves `813c52e`, verifies its tree hash, and extracts it with `git archive`
  into a temporary directory, leaving the checkout untouched;
- copies these same probe sources next to the extracted library and builds them
  against it; and
- requires every defect to be present.

It fails if either half disagrees. Because a full history is needed to resolve
the pinned revision, a shallow clone fails with a specific message rather than
quietly testing the wrong source.

The probe is also a plain executable:

```sh
cd IntegrationTests/BaselineProbe

swift run XPCCodingBaselineProbe list                    # checks and expectations
swift run XPCCodingBaselineProbe evidence --expect current
swift run XPCCodingBaselineProbe help
```

Built in place it links against the working tree, so `--expect current` is the
only meaningful expectation without the script.

## What each check pins down

| Checks | Defect at `813c52e` | Issue |
| --- | --- | --- |
| `percent-escape/*` (8) | `.percentEscape` unescaped unconditionally, so `%41` decoded as `A`, `100%` failed to decode, and `%25` lost its literal percent | [#7](https://github.com/plx/hdxl-xpc-coding/issues/7) |
| `percent-escape/key-collision-*` (2) | two distinct Swift keys collapsed onto one XPC key, silently dropping an entry | [#7](https://github.com/plx/hdxl-xpc-coding/issues/7) |
| `external-utf8/*` (4) | malformed UTF-8 was repaired into U+FFFD instead of rejected, as a value and as a key | [#16](https://github.com/plx/hdxl-xpc-coding/issues/16) |
| `representation/*` (4) | `Data` became one XPC object per byte; narrow integers and `Float` became raw native bytes | [#20](https://github.com/plx/hdxl-xpc-coding/issues/20), [#22](https://github.com/plx/hdxl-xpc-coding/issues/22), [#23](https://github.com/plx/hdxl-xpc-coding/issues/23) |
| `alignment/offset-narrow-integer` | binary numeric decoding loaded from an unaligned address | [#8](https://github.com/plx/hdxl-xpc-coding/issues/8) |
| `pointer-count/nil-pointer-positive-count` | an unvalidated pointer/count pair reached `xpc_data_create` | [#11](https://github.com/plx/hdxl-xpc-coding/issues/11) |
| `budgets/*` (2) | the decoder recursed with no depth budget, so a cycle or a deep graph ran until something gave out | [#9](https://github.com/plx/hdxl-xpc-coding/issues/9) |
| `control/*` (4) | nothing — these must behave identically at both revisions | |

The last four are what keep the result meaningful. A probe that had simply
broken everything, or that had been built against the wrong revision, would
otherwise look like a clean sweep of reproduced defects.

Two further protections apply before any child starts. Every defect check
declares the outcomes it requires at each revision, and those two sets must be
disjoint, or the check could pass at both revisions and prove nothing; every
control's two sets must be identical. `XPCCodingBaselineProbe` refuses to run an
inventory that violates either rule.

## Why the same sources build twice

The probe drives only public API that already existed at `813c52e`:
`XPCEncoder`, `XPCDecoder`, their string key and value strategies, and
`efficientlyEncodeBinaryData(_:count:)`. Nothing here mentions
`XPCDecoder.ResourceLimits`, `Int128`, or any other API the remediation program
introduced, so a single unedited source tree links against either library.

That matters because it is what makes the comparison evidence rather than
narration: the experiment is fixed, and only the revision behind it varies.

The package manifest resolves its dependency at `../..`, so the checked-in copy
builds against the repository root, and the copy the script places inside the
extracted revision builds against that revision — with the same manifest, unedited.

Both halves build in **debug**, and that is load-bearing. The unaligned load in
[#8](https://github.com/plx/hdxl-xpc-coding/issues/8) is undefined behavior, not
a guaranteed fault: an optimized arm64 build may complete it silently, while a
checked build traps exactly as the audit recorded. Building both halves the same
way keeps the library revision the only difference between them.

## Bounds

Three of these defects end the process at `813c52e`: two trap and two exhaust
the stack. Every check therefore runs in a fresh child under independent
ceilings, and the supervising parent never executes a check itself.

| Bound | Mechanism | Enforced by |
| --- | --- | --- |
| wall clock | `SIGKILL` after the deadline | parent, sampling every 10 ms |
| CPU time | `RLIMIT_CPU`, delivering `SIGXCPU` | kernel, set by the child on itself |
| memory | `SIGKILL` above a physical-footprint ceiling | parent, via `proc_pid_rusage` |
| core dumps | `RLIMIT_CORE` of zero | kernel, set by the child on itself |

`RLIMIT_AS` and `RLIMIT_DATA` are deliberately unused: Darwin rejects both with
`EINVAL`, so a probe that "set" them would report a memory bound it does not
have. A `setrlimit` failure is fatal rather than ignored, because a child that
silently ran unbounded would write a core dump for every trapping check.

The two budget checks accept any of the terminating outcomes, and the transcript
records which one occurred. Their defect is precisely that nothing bounds the
decode, so which resource gives out first — the stack, the footprint ceiling,
the CPU ceiling, the wall clock — is a property of the host rather than of the
defect. `unexpectedExit` is excluded from that set, because that is how a broken
probe reports itself.

Defaults are 15 s wall clock, 8 s CPU, and 1024 MiB per check, tunable through
`XPCCODING_BASELINE_TIMEOUT_SECONDS`, `XPCCODING_BASELINE_CPU_SECONDS`, and
`XPCCODING_BASELINE_MEMORY_MIB`. The whole run takes well under a minute.

## Coverage and its limits

A defect earns a check here when it can be demonstrated deterministically and
safely through the audit revision's own public API. Twenty-two of the audit's
findings meet that bar.

The rest do not, for reasons worth stating rather than leaving implicit:

- Defects whose observable difference is an `EncodingError` coding path, an
  error's identity, or `decodeNil` semantics need the corrected behavior *named*
  to be checked, which the current-revision suites do directly.
- The concurrency defect is a data race. Demonstrating it requires a sanitizer
  run rather than an outcome comparison, and the repository already runs
  dedicated ThreadSanitizer, AddressSanitizer, and UndefinedBehaviorSanitizer
  lanes.
- `(non-nil pointer, negative count)` is left alone deliberately. At `813c52e`
  that reaches `xpc_data_create` as a `size_t` of `SIZE_MAX`, which is a read
  past a real allocation rather than a contained fault. The `(nil, count > 0)`
  pair demonstrates the same missing validation without ever describing memory
  the probe does not own.

Ongoing hostile-input coverage of the *current* revision is a separate concern
and lives in [`IntegrationTests/Fuzzing`](../Fuzzing/README.md).
