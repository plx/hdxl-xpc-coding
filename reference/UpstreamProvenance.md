# Upstream Provenance and License Review

> Important: This document is a factual provenance record and an engineering
> compliance review. It is not legal advice.

## Status

The provenance inventory and compliance determination are complete. Repository
maintainer plx approved the determination recorded below on July 26, 2026.

## Pinned Revisions

The upstream project is
[`daniel-grumberg/CodableXPC`](https://github.com/daniel-grumberg/CodableXPC).
This review pins upstream revision
[`df3250371e7ad4882ec51b76dfbbbe7b00209fee`](https://github.com/daniel-grumberg/CodableXPC/tree/df3250371e7ad4882ec51b76dfbbbe7b00209fee).
That revision:

- is the tip of upstream `master`;
- is the current upstream `HEAD`;
- predates the local import by almost four years; and
- is the only upstream commit after 2018, changing only `README.md`.

Upstream implementation and test content was introduced by
[`dd9a20eaf1e452f3f1af5b6a6b39330a9c9a843b`](https://github.com/daniel-grumberg/CodableXPC/commit/dd9a20eaf1e452f3f1af5b6a6b39330a9c9a843b).
The implementation and test files are byte-identical at every upstream
revision from `dd9a20e` through `df32503`.

The local import is commit
[`68d3eaff9d5fe2a1b25bf876038bd835b1c7180b`](https://github.com/plx/hdxl-xpc-coding/commit/68d3eaff9d5fe2a1b25bf876038bd835b1c7180b).
It describes the package as a heavily-refactored fork but does not record an
upstream object ID. Because every candidate upstream revision has identical
implementation and test content, the exact checkout used during the import
cannot be recovered from file content alone. `df32503` is therefore the
conservative pinned baseline for this review, not an unsupported claim that
Git history proves which code-identical checkout was used.

The local pre-remediation baseline is
[`9afadad797a77d4f45c8bb513552b08eec92f068`](https://github.com/plx/hdxl-xpc-coding/commit/9afadad797a77d4f45c8bb513552b08eec92f068).

## Upstream License and Notice Facts

At `df32503`:

- `LICENSE.txt` contains the Apache License 2.0 followed by the Swift Runtime
  Library Exception;
- SPDX identifies that combined expression as
  `Apache-2.0 WITH Swift-exception`;
- all nine files under `Sources/CodableXPC` say
  `Licensed under Apache License v2.0 with Runtime Library Exception`;
- `Tests/CodableXPCTests/CodableXPCTests.swift` carries the same notice;
- those source notices contain no copyright, patent, or trademark attribution;
  and
- the upstream repository contains no `NOTICE` file.

The Runtime Library Exception is:

> As an exception, if you use this Software to compile your source code and
> portions of this Software are embedded into the binary product as a result,
> you may redistribute such product without providing attribution as would
> otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.

Canonical references:

- [upstream `LICENSE.txt` at `df32503`](https://raw.githubusercontent.com/daniel-grumberg/CodableXPC/df3250371e7ad4882ec51b76dfbbbe7b00209fee/LICENSE.txt)
- [Swift license and Runtime Library Exception](https://www.swift.org/legal/license.html)
- [SPDX `Swift-exception`](https://github.com/spdx/license-list-data/blob/main/json/exceptions/Swift-exception.json)
- [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)

## Local License and Notice Facts

At the local import commit `68d3eaf`:

- root `LICENSE` contained Apache License 2.0 without the upstream Runtime
  Library Exception;
- the nine directly-descended implementation files and the monolithic test
  file retained upstream's Runtime Library Exception notice;
- helper implementations extracted during the initial refactor did not carry
  the upstream notice; and
- `README.md` clearly described the project as a heavily-refactored fork and
  linked to upstream.

At the review baseline:

- root `LICENSE` is byte-identical to the file at `68d3eaf` and still omits
  the Runtime Library Exception;
- no file under `Sources` or `Tests` retains the upstream notice;
- `README.md` still clearly describes and links the fork; and
- neither `NOTICE` nor a third-party-notices document exists.

Apache License 2.0 section 4 requires a redistributed derivative work to ship
the license, identify modified files, retain pertinent source notices, and
preserve upstream `NOTICE` content when upstream supplied such a file. The last
condition has no upstream content to preserve here.

## Repository-Level File Map

- `.gitignore` was imported under the same name with modifications and was
  modified further afterward.
- `.travis.yml` was not imported. The later GitHub Actions workflow is locally
  authored.
- `LICENSE.txt` became `LICENSE` with the exception omitted. It has not changed
  since the import.
- `Package.swift` was substantially modified during import and afterward.
- `README.md` was replaced with fork-specific text and expanded locally.

Upstream has no `NOTICE` file, generated source, vendored dependency, or other
file requiring a descendant mapping.

## Implementation File Map

The mappings below are conservative. A current file is classified as derived
when it retains upstream implementation behavior or when the local import
extracted upstream helper behavior into that file. A file need not have been
detected as a Git rename to be classified as derived.

### Coding Key

`Sources/CodableXPC/XPCCodingKey.swift` maps to:

- `Sources/XPCCoding/Support/XPCCodingKey.swift`

### Decoder

`Sources/CodableXPC/XPCDecoder.swift` maps to:

- `Sources/XPCCoding/Decoding/XPCDecoder.swift`
- `Sources/XPCCoding/Decoding/Details/_XPCDecoder.swift`
- `Sources/XPCCoding/Decoding/Details/xpc_object_t+Extraction.swift`
- `Sources/XPCCoding/Protocols/XPCBinaryDataRepresentationConvertible.swift`
- `Sources/XPCCoding/Protocols/XPCObjectExtractable.swift`
- `Sources/XPCCoding/Support/xpc_object+Support.swift`

The public facade/internal decoder split and the primitive-extraction helpers
are reorganizations and extensions of the upstream decoder and its
`XPCDecodingHelpers`.

### Encoder

`Sources/CodableXPC/XPCEncoder.swift` maps to:

- `Sources/XPCCoding/Encoding/XPCEncoder.swift`
- `Sources/XPCCoding/Encoding/Details/_XPCEncoder.swift`
- `Sources/XPCCoding/Encoding/Details/String+xpc_object_t.swift`
- `Sources/XPCCoding/Protocols/LosslessXPCObjectConvertible.swift`
- `Sources/XPCCoding/Protocols/XPCBinaryDataRepresentationConvertible.swift`
- `Sources/XPCCoding/Support/xpc_object+Support.swift`

The public facade/internal encoder split and primitive-conversion helpers are
reorganizations and extensions of the upstream encoder and its
`XPCEncodingHelpers`.

### Decoding Containers

Each upstream decoding container has a same-named direct descendant under
`Sources/XPCCoding/Decoding/Details`:

- `XPCKeyedDecodingContainer.swift`
- `XPCSingleValueDecodingContainer.swift`
- `XPCUnkeyedDecodingContainer.swift`

Shared type-checking and extraction behavior from these files also moved into
`Sources/XPCCoding/Support/xpc_object+Support.swift`.

### Encoding Containers

Each upstream encoding container has a same-named direct descendant under
`Sources/XPCCoding/Encoding/Details`:

- `XPCKeyedEncodingContainer.swift`
- `XPCSingleValueEncodingContainer.swift`
- `XPCUnkeyedEncodingContainer.swift`

Upstream's keyed and unkeyed referencing-encoder implementations were
subsequently split into:

- `Sources/XPCCoding/Encoding/Details/_XPCDictionaryReferencingEncoder.swift`
- `Sources/XPCCoding/Encoding/Details/_XPCArrayReferencingEncoder.swift`

## Test File Map

Upstream's single
`Tests/CodableXPCTests/CodableXPCTests.swift` maps to:

- `Tests/XPCCodingTests/LegacyTests/OriginalCodableXPCTests.swift`
- `Tests/XPCCodingTests/LegacyTests/Support/Address.swift`
- `Tests/XPCCodingTests/LegacyTests/Support/Company.swift`
- `Tests/XPCCodingTests/LegacyTests/Support/Counter.swift`
- `Tests/XPCCodingTests/LegacyTests/Support/Employee.swift`
- `Tests/XPCCodingTests/LegacyTests/Support/EnhancedBool.swift`
- `Tests/XPCCodingTests/LegacyTests/Support/Mapping.swift`
- `Tests/XPCCodingTests/LegacyTests/Support/Numbers.swift`
- `Tests/XPCCodingTests/LegacyTests/Support/Person.swift`
- `Tests/XPCCodingTests/LegacyTests/Support/Programmer.swift`
- `Tests/XPCCodingTests/LegacyTests/Support/Switch.swift`
- `Tests/XPCCodingTests/LegacyTests/Support/Timestamp.swift`

The other current test files were added locally. They test the derivative work
but are not descendants of the upstream monolithic test file.

## Locally-Originated Files

All current files not identified above were added by local commits. In
particular, the codec facade, embedded-null handling, enhanced-container API,
decoder resource budgets, pointer validation, test infrastructure, expanded
test suites, documentation, task-runner configuration, and GitHub Actions
workflow have no upstream file-level ancestor.

The approved repository-wide license applies to both these locally-originated
files and the derived files mapped above.

## Evidence and Reproduction

The inventory was produced from immutable Git objects and the pinned upstream
revision. The central checks are:

```sh
git show --stat --summary 68d3eaf
git ls-tree -r --name-only 68d3eaf
git grep -n 'Runtime Library Exception' 68d3eaf -- Sources Tests
git grep -n 'Runtime Library Exception' 9afadad -- Sources Tests
git show 68d3eaf:LICENSE
git ls-remote https://github.com/daniel-grumberg/CodableXPC.git \
  HEAD refs/heads/master
git -C /path/to/CodableXPC ls-tree -r --name-only df32503
git -C /path/to/CodableXPC show df32503:LICENSE.txt
git show --find-renames=20% --find-copies=20% --summary ecc9a16
git show --find-renames=20% --find-copies=20% --summary 39cae7e
```

The direct rename history establishes the container and coding-key lineage.
The split commits, declaration-level comparison, and surviving behavior
establish the facade, helper, referencing-encoder, and legacy-test mappings.

## Compliance Determination

The approved repository-wide policy is:

1. distribute the package under `Apache-2.0 WITH Swift-exception`;
2. append the exact upstream Runtime Library Exception to root `LICENSE`;
3. restore the upstream license wording and a prominent modification notice in
   every derived implementation and legacy-test file listed above;
4. mark the modified `Package.swift` and `.gitignore` as changed from upstream;
5. add a durable `THIRD_PARTY_NOTICES.md` that identifies CodableXPC, Daniel
   Grumberg and upstream contributors, the pinned revision, and the applicable
   license, while accurately stating that upstream supplied no `NOTICE`;
6. expand the README's existing fork attribution with the pinned revision and
   license expression; and
7. keep this document as the durable file-level provenance record.

This policy restores the terms and notices upstream actually distributed and
applies one license expression to the whole package.

### Sign-Off

- Reviewer: plx
- Role: repository maintainer
- Date: July 26, 2026
- Determination: approved explicitly as written
