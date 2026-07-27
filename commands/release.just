set quiet

[private]
default:
    @just --list release --unsorted

# diff the public API against the pinned hardened baseline (fail-closed)
[group('api')]
verify-api-stability:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    bash Scripts/verify-api-stability.sh

# validate the committed Swift Package Index metadata against the package
[group('metadata')]
verify-spi-metadata:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    bash Scripts/verify-swift-package-index-metadata.sh

# reproduce the intentional source-API breaks against the 0.0.3 lightweight tag
# (informational: the tool exits 1 because the hardening breaks are expected)
[group('api')]
diff-api-since-0-0-3:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    swift package diagnose-api-breaking-changes 0.0.3 --products XPCCoding || true

# clean-clone rehearsal of release mechanics (publishes nothing)
[group('rehearsal')]
rehearsal candidate='HEAD' destination='':
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    bash Scripts/release-rehearsal.sh {{ quote(candidate) }} {{ quote(destination) }}
