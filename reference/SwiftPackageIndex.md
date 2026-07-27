# Swift Package Index metadata

The repository contains a deliberately narrow
[Swift Package Index manifest](../.spi.yml). It configures the `XPCCoding`
library and documentation without broadening the project's support policy.

## Authoritative identity

| Item | Value |
| --- | --- |
| Package identity | `hdxl-xpc-coding` |
| Canonical repository URL | `https://github.com/plx/hdxl-xpc-coding.git` |
| Library product | `XPCCoding` |
| Swift module/target | `XPCCoding` |
| Documentation target | `XPCCoding` |
| Swift version | `6.3` |
| Supported platforms | macOS 26+, iOS 26+, Mac Catalyst 26+ |

The package manifest and [support policy](SupportPolicy.md), not Package Index
build attempts, are the authoritative compatibility contract.

## Configuration

The manifest uses schema version 1 and three exact Swift 6.3 builder
configurations:

- `macos-spm`, targeting `XPCCoding` and generating its documentation;
- `macos-xcodebuild`, using the `XPCCoding` scheme; and
- `ios`, using the `XPCCoding` scheme.

This follows the official
[SPIManifest 1.13.0 schema](https://github.com/SwiftPackageIndex/SPIManifest/tree/1.13.0)
and its
[common-use-case guidance](https://github.com/SwiftPackageIndex/SPIManifest/blob/1.13.0/Sources/SPIManifest/Documentation.docc/CommonUseCases.md).
Version 1.13.0 identifies Swift 6.3 as the latest release known to the schema.

## Deterministic validation

Run:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
just release verify-spi-metadata
```

The command uses the same `SPIManifest` parser as the service, pinned at
version 1.13.0 with a committed SwiftPM resolution. It additionally rejects
unknown or stale local fields and verifies the exact configs, supported
toolchain/platform declarations, package/product/module/documentation target,
and canonical repository URL. The supported CI quality job runs this same
command.

The Package Index also provides an
[online manifest validator](https://swiftpackageindex.com/validate-spi-manifest).
It is useful as a manual service check, but it is external and therefore is not
the repository's deterministic release gate.

## Service limitations

The service's current platform vocabulary has no Mac Catalyst builder value,
so `.spi.yml` cannot request the supported Mac Catalyst configuration. The
repository's required Mac Catalyst compile job remains the evidence for that
platform.

The service may attempt platforms or Swift versions outside this project's
support policy, and its
[build FAQ](https://swiftpackageindex.com/docs/builds) says maintainers cannot
hide those unsupported build results. A failed or grey unsupported matrix cell
does not change XPCCoding's support contract. Documentation generation is
currently limited by the service to macOS, iOS, and Linux, so this package
generates documentation on macOS.

Default-branch metadata changes may take up to 24 hours to be processed.
Release processing begins only after an actual release exists.

## Publication boundary

Committing and validating `.spi.yml` does not submit the repository, create a
semantic tag, or create a GitHub Release. Those are publication actions and
remain gated by the production-readiness audit and the post-audit publication
ticket.
