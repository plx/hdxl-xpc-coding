# API Documentation

XPCCoding builds its DocC documentation with the one supported toolchain and
nothing else: SwiftPM emits the public symbol graphs for the `XPCCoding`
target and that toolchain's DocC compiles them. The pinned toolchain from the
[support policy](SupportPolicy.md) — Xcode 26.6 (build 17F113) with Apple
Swift 6.3.3 — is therefore the complete set of documentation tooling inputs.
There is no package dependency, no separately-versioned plugin, and nothing to
resolve, so a clean clone reproduces the archive offline.

Generate it from the repository root, naming the output directory explicitly:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash Scripts/generate-api-documentation.sh "$(mktemp -d)"
```

`just docs generate-documentation <output-directory>` invokes exactly that
script, and CI's `API documentation` job runs the identical command against
`${RUNNER_TEMP}/documentation` after verifying the support policy. There is no
second, separately-maintained documentation recipe to drift.

The script writes `<output-directory>/XPCCoding.doccarchive`. That archive is
generated output: it belongs in a temporary or otherwise disposable directory,
and `*.doccarchive` is ignored so it cannot be committed by accident.

The run fails nonzero when:

- the build emits no `XPCCoding` symbol graph;
- DocC reports any warning, including an unresolved symbol link, because the
  conversion passes `--warnings-as-errors`; or
- the archive does not contain the `XPCCoding` module.

To confirm the strictness gate, temporarily point a doc comment at a symbol
that does not exist, such as ``XPCCoding/NoSuchSymbol``, and rerun the command:
DocC reports `error: 'NoSuchSymbol' doesn't exist at ...` and the script exits
nonzero without writing an archive. Without `--warnings-as-errors` that same
diagnostic is only a warning and the run succeeds.

## Why this shape

The Swift-DocC plugin is upstream's preferred route for packages, but adopting
it would give this package its only dependency, plus that plugin's own
`swift-docc-symbolkit` dependency, and would make documentation depend on
dependency resolution. The toolchain already ships everything required, so the
package stays dependency-free.

`swift package dump-symbol-graph` is the documented toolchain-direct way to
obtain symbol graphs, but it also extracts the package's test bundle module,
which fails under the supported toolchain (`Couldn't load module
'hdxl_xpc_codingPackageTests'`) and exits nonzero. Building the `XPCCoding`
target with the compiler's `-emit-symbol-graph` flags avoids that and emits
exactly the public surface being documented.
