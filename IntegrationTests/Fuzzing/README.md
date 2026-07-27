# Deterministic Property and Hostile-Input Fuzzing

This macOS-only harness attacks XPCCoding's public invariants with seeded
property generation, mutation of a reviewed corpus, and a checked-in inventory
of every historical reproducer.

It exists because high line coverage did not find the audit's corruption and
crash defects: important inputs were filtered out, output *shapes* were never
asserted, and hostile `xpc_object_t` graphs were never generated. This harness
generates them, asserts shapes, and runs every case in a bounded child process.

It is completely isolated from the shipped library. It adds no runtime code, no
public API, no representation change, and no version, envelope, or neutral-byte
machinery. It depends on `XPCCoding` exactly the way an application does, by
local path, and uses only public APIs.

## Properties under test

| Property | Where |
| --- | --- |
| supported values round-trip exactly, scalar-for-scalar | `models`, `strings`, `representation` |
| distinct strings and keys never alias under a total strategy | `strings`, `keys` |
| encoder output has the documented XPC kinds and shapes | every probe asserts `xpc_get_type` |
| arbitrary supported graphs decode or throw, never crash or hang | `graph`, `cycles`, mutation |
| malformed lengths, offsets, UTF-8, escapes, cycles, and budgets stay safe | `binary128`, `raw-text`, `cycles`, `budgets` |
| unsafe pointer/count pairs are validated before libxpc is called | `pointer-count` |

Expectations come in three strengths. `pass` requires success and every
assertion; `reject` requires a public `DecodingError` or `EncodingError`;
`tolerant` requires *either*, and forbids a crash, trap, hang, internal error
type, or breached bound. Nothing is ever a tolerated finding.

## Run

From the repository root, with the
[supported Xcode toolchain](../../reference/SupportPolicy.md) selected:

```sh
# Bounded, fixed-seed campaign. This is the pull-request recipe.
bash Scripts/run-fuzzing-smoke.sh

# Long campaign with durable artifacts. This is the scheduled/manual recipe.
bash Scripts/run-fuzzing-campaign.sh
```

Both scripts build in release with warnings as errors, verify the corpus, prove
the timeout and minimizer controls work, and then run the campaign. Their
behavior is tunable through `XPCCODING_FUZZING_*` environment variables; see the
top of each script.

The harness itself is a plain executable:

```sh
cd IntegrationTests/Fuzzing

swift run XPCCodingFuzzing corpus                     # run every checked-in case
swift run XPCCodingFuzzing corpus verify              # JSON matches the inventory
swift run XPCCodingFuzzing corpus list                # identifiers, seeds, kinds
swift run XPCCodingFuzzing campaign --smoke           # corpus + generated + mutated
swift run XPCCodingFuzzing determinism                # fixed-seed stability evidence
swift run XPCCodingFuzzing verify-timeout             # deliberate-hanger control
swift run XPCCodingFuzzing verify-memory              # footprint-ceiling control
swift run XPCCodingFuzzing verify-minimizer           # detect/shrink/persist control
swift run XPCCodingFuzzing self-test                  # all of the above, bounded
swift run XPCCodingFuzzing help
```

## Seeds and replay

Every case carries a seed, and every diagnostic prints it. A case is a pure
value, so replay never depends on the run that produced it:

```sh
# A generated case, from the campaign's root seed and the case index.
swift run XPCCodingFuzzing replay --seed 0x5eed000000000001 --index 312

# A checked-in case, by identifier.
swift run XPCCodingFuzzing replay --case-id keys/collision-9/assumeAbsent

# Any persisted counterexample, including a minimized one.
swift run XPCCodingFuzzing replay --case .build/fuzzing/campaign/counterexamples/mutated-312-minimized.json
```

Replay always crosses the process boundary, and there is no in-process escape.
A case that is safe today can become a trap or a hang after any change, so an
unbounded debug path would quietly undo the guarantee that every hostile case
runs supervised. To attach a debugger, attach it to the `run-case` child.

Generation uses a written-out SplitMix64 rather than
`SystemRandomNumberGenerator`, which cannot be seeded, or the standard library's
seeded generators, whose value sequences are not a stability contract. Each case
seed is derived from the root seed and the case index alone, so replaying case
312 never requires generating the 311 before it.

`determinism` is the evidence: it builds the case list several times, compares a
canonical digest, and re-executes a subset, requiring one digest and identical
outcomes. Every campaign report also records the corpus digest and the case
digest of the population it ran.

## Bounds

Every case — including every hostile one — runs in a fresh child process under
three independent ceilings, because the failure modes are independent. A defect
that spins without allocating is caught by CPU time, one that blocks without
spinning by the wall clock, and one that allocates without spinning by the
footprint ceiling.

| Bound | Mechanism | Enforced by |
| --- | --- | --- |
| wall clock | `SIGKILL` after the deadline | parent, sampling every 10 ms |
| CPU time | `RLIMIT_CPU`, delivering `SIGXCPU` | kernel, set by the child on itself |
| memory | `SIGKILL` above a physical-footprint ceiling | parent, via `proc_pid_rusage` |
| core dumps | `RLIMIT_CORE` of zero | kernel, set by the child on itself |

`RLIMIT_AS` and `RLIMIT_DATA` are deliberately unused: Darwin 26/27 rejects both
with `EINVAL`, so a harness that "set" them would report a memory bound it does
not have. The parent's footprint sampling is the real ceiling.

The child installs its own ceilings before it reads the descriptor, so even a
hostile or corrupt descriptor file is parsed under the CPU ceiling and with core
dumps already disabled. A `setrlimit` failure ends the child with a distinct
status rather than being ignored, because a child that silently ran unbounded
would turn a CPU overrun into an indefinite hang and a trap into a core dump.

A crash, trap, timeout, CPU overrun, or footprint overrun is a *failure*, never
a finding to triage later. The child's exit code separates a completed probe that
violated its expectation (65) from a process the kernel or the parent stopped.

Three negative controls run on every pull request, because a harness whose own
machinery has silently stopped working reports success forever.

`Corpus/deliberate-hang.json` is a case that never returns. The ordinary corpus
run skips it; `verify-timeout` runs exactly it, and requires that the wall-clock
control kill it and that the emitted diagnostic contain its seed.

`verify-memory` runs the same hanger under a ceiling below any Swift process's
resident footprint, and requires the *memory* outcome rather than the timeout.
This one matters most: the wall clock and the CPU ceiling announce themselves the
first time they stop something, but no case in this corpus allocates near the
footprint ceiling, so a sampler that had stopped working would be
indistinguishable from a sampler with nothing to catch. If it were broken, the
hanger would survive to the wall clock and the control would fail.

`verify-minimizer` is the control for the failure path: it plants a synthetic
failing descriptor and requires that the harness detect it, shrink it, and
persist a case that reproduces.

## The corpus

`Corpus/*.json` is the durable, replayable form. The reviewed origin is typed
Swift source in
[`HistoricalCorpus.swift`](Sources/XPCCodingFuzzing/HistoricalCorpus.swift).
`corpus verify` fails when the two disagree, so the JSON is never silently
regenerated to match new behavior; `corpus regenerate` rewrites it for review.

| Theme | Cases | Coverage |
| --- | ---: | --- |
| `strings` | 20 | the audit's string corpus, literal percent, embedded null, combining marks, and Unicode planes, across all four total value strategies |
| `keys` | 26 | key sets that historically aliased, under `.percentEscape` and the deliberately-lossy `.assumeAbsent` |
| `raw-text` | 128 | malformed UTF-8 and the complete percent-escape grammar, as string values and dictionary keys, under both decoder strategies |
| `binary128` | 32 | `Int128`/`UInt128` at 0, 1, 8, 15, 16, 17, 24, and 32 bytes, from aligned and offset storage |
| `budgets` | 30 | every resource at limit−1, limit, and limit+1, plus a zero ceiling |
| `cycles` | 7 | empty, value-bearing, and mutual array and dictionary cycles, plus shared acyclic children |
| `pointer-count` | 48 | container shape × mutability × nil-ness × count, including negative, zero, positive, and full-extent |
| `representation` | 38 | `Data` sizes, narrow integer boundaries, and `Float16`/`Float`/`Double` zeros, subnormals, infinities, and NaNs |
| `models` | 8 | whole hostile and empty models across all four strategies |
| `deliberate-hang` | 1 | the timeout control |
| **total** | **338** | `corpus verify` fails if this inventory and the JSON disagree |

Two properties of this corpus are worth stating explicitly.

Budget cases derive every *non-target* ceiling from the case's own observed
count, so the resource the descriptor names is the only one that can bind. A
rejection must name that exact public limit property, which keeps a mutated
budget case from passing for an unrelated reason.

Pointer cases never claim more bytes than the probe's initialized extent. A raw
pointer carries no extent metadata, so a larger count would be undefined
behavior rather than a test; the harness rejects such a descriptor instead of
handing it to libxpc. The `(nonnull, count > allocation)` boundary remains a
matter of API-contract review, as the audit requires.

## Mutation

Mutation is structural, not byte-level: it rewrites typed descriptor fields, so
every derived case is still a well-formed instruction. The hostility is in the
values.

A mutated case cannot inherit its ancestor's verdict. Where an expectation is a
function of content — 128-bit byte count, budget over/under, pointer/count
validity, cyclic versus shared — it is recomputed. Where it is not, such as UTF-8
validity or escape grammar, the case weakens to `tolerant`. Without this, a
campaign would report failures that are really just stale expectations.

## Counterexamples

Every failure is minimized and persisted. Reductions are enumerated
deterministically and a candidate is accepted only when it still fails at least
as severely, so minimizing the same counterexample twice yields the same
artifact. Both the original and the minimized descriptor are written under
`counterexamples/`, alongside `campaign.json`.

Minimization preserves a `reject` verdict, because "this input was wrongly
accepted" stays meaningful as the input shrinks, and weakens a `pass` verdict
whose reviewed decoded text no longer describes the reduced bytes.

The campaign has already found one counterexample, now checked in as
`keys/collision-9` and `keys/collision-10`: after `.assumeAbsent` truncation,
`"e\u{301}"` and `"é"` are **one** Swift dictionary key by canonical equivalence
but **two** distinct XPC dictionary keys, because an XPC key is identified by its
bytes. The library was correct and the harness's oracle was not. The reproducer
is retained so no future oracle re-introduces the confusion.

## Regression-first evidence

Each corpus theme above encodes the inputs of a specific audit finding and
asserts the *corrected* behavior. That shows the defects are gone; it cannot by
itself show they were ever there.

The other half of that claim lives in
[`IntegrationTests/BaselineProbe`](../BaselineProbe/README.md), which runs on
every pull request. It exists as a separate package for a concrete reason: this
harness drives public API the remediation program introduced —
`XPCDecoder.ResourceLimits`, `Int128`/`UInt128`, `.passthrough` string
strategies — so it cannot compile against `813c52e` at all. The baseline probe
deliberately drives only the API that revision already had, which lets one
unedited source tree build against either library and be required to produce a
different answer from each.

Between them: the baseline probe proves twenty-two audit findings reproduce at
`813c52e` and are absent today; this harness keeps generating new hostile input
against the corrected behavior.
