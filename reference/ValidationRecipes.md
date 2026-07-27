# Validation Recipes

XPCCoding has no compile-time "heavy validation" mode. A compiler flag that no
source or test reads is not validation, so the former `HEAVY_VALIDATION`
debug/release variants were removed.

Build recipes now describe the only two real configurations:

```sh
just build debug
just build release
just build all
```

`build all` depends on exactly `debug` and `release`.

## Test groups

Standard unit tests are:

```sh
just test debug
just test release
just test all-standard
```

The bounded validation leaves perform distinct work:

- `address-sanitizer`, `thread-sanitizer`, and
  `undefined-behavior-sanitizer` run the complete suite under separate dynamic
  analyzers;
- `fuzz-smoke` runs the fixed-seed, bounded fuzzing campaign;
- `hostile-input` runs subprocess-isolated invalid-input and expected-crash
  regressions from a fresh scratch build;
- `xpc-integration` performs three deterministic request/reply exchanges
  across a real application/service process boundary; and
- `recipe-contracts` verifies the machine-readable `just` dependency graph.

`just test all-sanitizers` runs exactly the three sanitizer leaves.
`just test all-validation` runs the recipe contract, all sanitizers, fuzz
smoke, hostile-input regressions, and XPC integration. `just test all` combines
`all-standard` and `all-validation`.

The long fuzz campaign and historical baseline reproduction remain explicit,
separate commands because they are not part of the bounded aggregate:

```sh
just test fuzz-campaign
just test baseline-evidence
```

## CI ownership

The supported workflow calls the same scripts as every executable validation
leaf:

| Validation | Canonical command | CI owner |
| --- | --- | --- |
| address sanitizer | `Scripts/run-sanitizer-tests.sh address` | Address Sanitizer |
| thread sanitizer | `Scripts/run-sanitizer-tests.sh thread` | Thread Sanitizer |
| undefined-behavior sanitizer | `Scripts/run-sanitizer-tests.sh undefined` | Undefined Behavior Sanitizer |
| hostile input | `Scripts/run-hostile-input-tests.sh` | Address and Thread Sanitizer |
| fuzz smoke | `Scripts/run-fuzzing-smoke.sh` | Deterministic fuzzing smoke |
| XPC integration | `Scripts/run-xpc-integration.sh` | Same-host XPC request/reply |

`Scripts/verify-just-recipe-contracts.sh` rejects obsolete validation-variant
names, any remaining `HEAVY_VALIDATION` reference in implementation or recipe
files, and any aggregate whose dependency set differs from the groups described
above.
It is the local preflight for aggregate wiring; final CI quality-gate assembly
owns installing its `just`, `jq`, and ripgrep prerequisites and adding the
preflight as a required check.
