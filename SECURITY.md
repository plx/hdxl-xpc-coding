# Security Policy

## Supported versions

Security fixes are provided only for the most recent GitHub Release. Older
releases, unreleased commits, and forks are not supported. Until the first
GitHub Release is published, there is no supported released version.

XPCCoding's supported operating envelope is the one documented in the
[README](README.md): jointly developed, same-build processes communicating on
one Apple host through XPC. Network transport, persistent or architecture-
neutral archives, and independently versioned peers are outside that envelope.

## Report a vulnerability privately

Do not disclose a suspected vulnerability in a public issue, discussion, pull
request, or test fixture. Use GitHub's
[private vulnerability reporting form](https://github.com/plx/hdxl-xpc-coding/security/advisories/new)
instead.

Include:

- the affected release and Apple platform;
- the Xcode and Swift versions;
- the smallest practical reproducer or a precise description of the input;
- the security impact and expected behavior; and
- any disclosure deadline or coordination constraints.

Do not include real credentials, production XPC payloads, or other sensitive
data. A minimized synthetic reproducer is preferred.

## Response expectations

This project is maintained by one person and does not offer a service-level
agreement. The maintainer will make a best effort to acknowledge a complete
report within seven calendar days and provide an initial disposition within
30 days. Complex reports, unavailable hardware, or personal circumstances may
require more time.

If a report is accepted, the reporter and maintainer should coordinate
disclosure through the private advisory. A fix, release date, CVE assignment,
credit, or bounty is not promised. Reports outside the supported operating
envelope may be closed without a code change.
