# SwiftLint

XPCCoding's lint policy is defined for SwiftLint 0.65.0. Every lint,
documentation-check, TODO-check, and summary recipe first runs
`Scripts/verify-swiftlint-version.sh`; a missing or different executable fails
before linting begins.

The official 0.65.0 release supports Swift 6 and publishes
`portable_swiftlint.zip` with SHA-256
`d6cb0aa7a2f5f1ef306fc9e37bcb54dc9a26facc8f7784ac0c3dd3eccf5c6ba6`.
Homebrew can install the current release with `brew install swiftlint`, but its
formula follows upstream releases rather than preserving this repository's
pin. After installation, verify the required version:

```sh
bash Scripts/verify-swiftlint-version.sh
```

## Rule ownership

SwiftLint owns semantic and structural checks. `swift-format` owns whitespace
and layout; overlapping colon, comma, whitespace, brace, line-length, and
switch-case-layout rules are disabled in `.swiftlint.yml` so the two tools
cannot disagree about formatting.

The remaining project-specific exceptions are explicit:

- Codable implementations may catch arbitrary user-thrown errors without a
  misleading type cast.
- Complexity warns at 20 and fails at 30, retaining a useful guard without
  rejecting small exhaustive representation switches.
- The nested `Tests/.swiftlint.yml` permits Swift Testing's descriptive
  backticked names and force unwraps used with fixed literals or values proven
  valid by construction. Those exceptions do not apply to production sources.
- Conventional one-letter fixture fields and the fixed-size `InlineArray`
  generic value parameter are listed by exact name instead of weakening the
  minimum identifier length globally.

## Blocking checks and summaries

These recipes are strict gates and return nonzero for any finding:

```sh
just lint check-all
just docs check-all
just todos check-all
```

Their `check-file`, `check-sources`, and `check-tests` variants are blocking as
well. Documentation completeness is expected to remain red until issue #38
finishes that work; the command is nevertheless fail-closed now.

Recipes under the `summarize` group are deliberately nonblocking for lint
findings and are named `summarize-*`. They use SwiftLint's lenient mode so
findings remain visible while tool, version, and configuration failures still
return nonzero.
