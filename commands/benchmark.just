# Run the complete release benchmark suite.
[group('benchmark')]
benchmark *arguments:
    swift run -c release XPCCodingBenchmarks run {{arguments}}

# Run the short, threshold-free release benchmark suite used by CI.
[group('benchmark')]
benchmark-smoke output=".build/benchmarks/smoke.json":
    swift run -c release XPCCodingBenchmarks run --smoke --output {{quote(output)}}

# Compare two reports and fail on missing scenarios or excessive median regressions.
[group('benchmark')]
benchmark-compare baseline candidate threshold_percent="10":
    swift run -c release XPCCodingBenchmarks compare {{quote(baseline)}} {{quote(candidate)}} --threshold-percent {{quote(threshold_percent)}}

# Exercise the comparator's missing-scenario and regression checks.
[group('benchmark')]
benchmark-self-test:
    swift run -c release XPCCodingBenchmarks self-test
