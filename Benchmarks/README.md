# XPCCoding benchmarks

`XPCCodingBenchmarks` is a release-only microbenchmark executable. It imports
`XPCCoding` normally, so every measured path is available to package clients;
the harness has no `@testable` access.

Run release evidence with the repository's
[supported Xcode and Swift toolchain](../reference/SupportPolicy.md).

The suite measures primitive and nested model encoding/decoding, moderate
nesting, large arrays and dictionaries, all string key/value strategies,
percent- and null-heavy strings, and `Data` at 0 B, 1 KiB, 64 KiB, and 1 MiB.
Each `Data` size covers top-level, keyed, and unkeyed encoding and decoding,
plus the public direct-buffer encoding path.

## Run

Use an otherwise-idle machine, keep it connected to power, and avoid comparing
runs made under meaningfully different thermal or power conditions.

```sh
just benchmark
```

The default report is `.build/benchmarks/latest.json`. To select scenarios or
change the sampling configuration:

```sh
just benchmark \
  --output .build/benchmarks/data.json \
  --filter data/ \
  --warmup 3 \
  --samples 15 \
  --target-sample-ms 100
```

Multiple `--filter` values are combined with OR semantics. `list` prints every
stable scenario name:

```sh
swift run -c release XPCCodingBenchmarks list
```

The harness calibrates a batch size for each scenario, performs untimed warmup
batches, and then records independent timed samples. Each operation's result is
consumed into a reported checksum so the optimizer cannot discard the work.
Large payloads have bounded batch sizes to avoid turning calibration into a
memory-pressure test.

The JSON report records:

- the schema version and run configuration;
- timestamp, OS, architecture, hardware model, processor count, physical
  memory, Swift and Xcode versions, measured and harness Git commits, dirty
  state, and `-O` release configuration;
- raw nanoseconds-per-operation samples, median, p90, p95, p99, mean, standard
  deviation, operations/second, and bytes/second where a logical byte count
  exists; and
- the encoded XPC-object count observed while constructing each scenario.

The object count is intentionally useful for tracking `Data` representation
amplification. It describes the in-memory XPC object graph, not a stable wire
format or a compatibility promise.

## Compare

Capture both reports on the same machine under comparable conditions:

```sh
just benchmark --output .build/benchmarks/baseline.json
# switch to the candidate revision and rebuild
just benchmark --output .build/benchmarks/candidate.json
just benchmark-compare \
  .build/benchmarks/baseline.json \
  .build/benchmarks/candidate.json \
  10
```

The final argument is the permitted median regression percentage (10 by
default). The comparator fails if either report is missing a scenario or if a
candidate median exceeds the threshold. Thresholds are a local investigation
aid, not a CI gate: shared runners are too noisy for trustworthy microbenchmark
regression limits.

`just benchmark-smoke` runs seven representative scenarios with short samples.
CI uses it only to detect build, execution, schema, and result-consumption
failures, then uploads the JSON report as an artifact. `just
benchmark-self-test` checks that the comparator detects regressions and
scenario-set mismatches.

## Audit baseline

The production-readiness audit identified commit `813c52e` as the pre-fix
baseline. To compare it with a candidate without changing the audit commit,
apply only `Package.swift` and `Benchmarks/` from the benchmark-harness commit
to a detached worktree. Build that worktree with
`-Xswiftc -DBENCHMARK_AUDIT_BASELINE`; this omits the later decoder resource
limit argument while leaving measured codec behavior unchanged:

```sh
XPCCODING_BENCHMARK_MEASURED_COMMIT=813c52e \
XPCCODING_BENCHMARK_HARNESS_COMMIT=<harness-commit> \
swift run -c release \
  -Xswiftc -DBENCHMARK_AUDIT_BASELINE \
  XPCCodingBenchmarks run \
  --output .build/benchmarks/audit-813c52e.json
```

The two environment variables make the measured library revision and
transplanted harness revision explicit in the report. Never compare an audit
report with a candidate report produced by a different harness revision.
