# API Documentation

XPCCoding builds its DocC documentation with the one supported toolchain and
nothing else: SwiftPM emits the public symbol graphs for the `XPCCoding`
target and that toolchain's DocC compiles them. The pinned toolchain from the
[support policy](SupportPolicy.md) — Xcode 26.6 (build 17F113) with Apple
Swift 6.3.3 — is therefore the complete set of documentation tooling inputs.
There is no package dependency, no separately-versioned plugin, and nothing to
resolve, so a clean clone reproduces the archive offline. The completeness gate
described below additionally needs `jq`, which the repository already requires
for `Scripts/verify-public-api.sh`.

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
- any public declaration in those symbol graphs lacks a documentation comment
  (see [Public-documentation completeness](#public-documentation-completeness));
- DocC reports any warning, including an unresolved symbol link, because the
  conversion passes `--warnings-as-errors`; or
- the archive does not contain the `XPCCoding` module.

To confirm the strictness gate, temporarily point a doc comment at a symbol
that does not exist, such as ``XPCCoding/NoSuchSymbol``, and rerun the command:
DocC reports `error: 'NoSuchSymbol' doesn't exist at ...` and the script exits
nonzero without writing an archive. Without `--warnings-as-errors` that same
diagnostic is only a warning and the run succeeds.

## Public-documentation completeness

`Scripts/verify-public-documentation.sh` is the repository's single
public-documentation completeness gate. It fails when any public declaration
lacks a documentation comment. `generate-api-documentation.sh` invokes it with
the symbol graphs it has already emitted, so completeness and strict DocC are
enforced by one build, and CI's `API documentation` job gets both from the
command it already runs. There is no second completeness rule to drift.

Run it on its own — it emits its own symbol graphs — with either of:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash Scripts/verify-public-documentation.sh

just docs check-public-api-completeness
```

The gate reads the public symbol graphs rather than the source text, so its
notion of "public declaration" is the compiler's: extension members, protocol
requirements, default implementations, conformance witnesses such as
`description`, type aliases, and members of extensions on standard-library
types (which land in `XPCCoding@Swift.symbols.json`) are all covered.

A public symbol that carries no source location is synthesized by the compiler —
for example the `init(from:)` of a synthesized `Codable` conformance, or a
`!=` operator from `Equatable`. No doc comment can be attached to such a
declaration, so the gate exempts it, and prints every exemption by name so the
exempt set stays reviewable instead of silently absorbing omissions.

`just docs check-sources` still runs SwiftLint's `missing_docs` rule. That
remains useful as a fast, file-scoped developer aid, but it is deliberately not
the gate: with SwiftLint's default `excludes_inherited_types`, an undocumented
`description` witness in a `CustomStringConvertible` extension passes
`missing_docs` and fails this gate. `just docs check-all` runs both.

To confirm the gate, add a public declaration with no doc comment and rerun it:
the run lists the declaration with its file, line, symbol path, and kind, and
exits nonzero. Run through `generate-api-documentation.sh` and no archive is
written, because the check precedes the DocC conversion.

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
