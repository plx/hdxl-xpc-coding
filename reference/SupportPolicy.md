# XPCCoding Support Policy

XPCCoding intentionally maintains one narrow build and deployment envelope.
This keeps release evidence precise and matches the package's co-built local
XPC use case.

## Supported toolchain

The sole supported toolchain is:

- Xcode 26.6, build 17F113;
- Apple Swift 6.3.3
  (`swiftlang-6.3.3.1.3`, `clang-2100.1.1.101`);
- Swift tools version 6.3; and
- Swift language mode 6.

Earlier Xcode or Swift versions are unsupported. Later versions, including
beta toolchains, are unverified until this policy is deliberately revised.
A successful build with another compiler is useful diagnostic information,
not a support commitment.

CI selects `/Applications/Xcode_26.6.app` explicitly on the arm64
`macos-26` GitHub-hosted runner. It does not rely on the runner's default Xcode
selection. The repository's support-policy check verifies both the Xcode
release and build number and the arm64 host architecture before building.

## Supported platforms

The package supports arm64 and declares exactly these minimum deployment
targets:

- macOS 26.0;
- iOS 26.0; and
- Mac Catalyst 26.0.

It does not claim support for older deployment targets or additional Apple
platforms. Intel macOS and x86_64 simulator targets are unsupported. Do not add
back-deployment shims, lower the declared versions, or introduce an
older-toolchain or x86_64 matrix as incidental maintenance work.

The XPC object representation is for compatible, same-host processes built
from the same package revision and toolchain. Toolchain support does not imply
cross-release, cross-architecture, persistent, or network interchange. See
[XPCCoding XPC Object Representation](WireFormat.md) for that compatibility
boundary.

## Verification

From a checkout using Xcode 26.6:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash Scripts/verify-support-policy.sh
```

The check prints the complete `xcodebuild -version` and `swift --version`
output, then verifies:

- Xcode 26.6 build 17F113;
- Apple Swift 6.3.3;
- an arm64 host;
- `// swift-tools-version:6.3`;
- Swift language mode 6; and
- exactly the three 26.0 deployment targets above.

Release evidence must also include debug and release tests plus compile checks
for arm64 macOS, iOS, and Mac Catalyst using this same toolchain. The
[post-remediation audit](PostRemediationProductionReadinessAudit.md) defines
the final release gate.

## Changing this policy

A policy change is a reviewed compatibility and release decision. It must
update the manifest, CI assertions, README, audit instructions, and relevant
compatibility documentation together. Passing opportunistically on an
unverified compiler or platform does not change this file.
