set quiet

[private]
default:
    @just --list test --unsorted

# run the complete unit suite in debug
[group('debug')]
[group('standard')]
debug:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    swift test -q

# run the complete unit suite in release
[group('release')]
[group('standard')]
release:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    swift test -q -c release

# run the complete suite under AddressSanitizer
[group('sanitizers')]
[group('validation')]
address-sanitizer:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    bash Scripts/run-sanitizer-tests.sh address

# run the bounded deterministic fuzzing smoke campaign
[group('fuzzing')]
[group('validation')]
fuzz-smoke:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    bash Scripts/run-fuzzing-smoke.sh

# run the long deterministic fuzzing campaign (durable artifacts)
[group('fuzzing')]
fuzz-campaign:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    bash Scripts/run-fuzzing-campaign.sh

# run subprocess-isolated hostile-input and expected-crash regressions
[group('hostile-input')]
[group('validation')]
hostile-input:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    bash Scripts/run-hostile-input-tests.sh

# prove the audited defects reproduce at 813c52e and are absent today
[group('regression')]
baseline-evidence:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    bash Scripts/run-baseline-evidence.sh

# verify that aggregate recipes retain their reviewed dependency contracts
[group('check')]
[group('validation')]
recipe-contracts:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    bash Scripts/verify-just-recipe-contracts.sh

# run the complete suite under ThreadSanitizer
[group('sanitizers')]
[group('validation')]
thread-sanitizer:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    bash Scripts/run-sanitizer-tests.sh thread

# run the complete suite under UndefinedBehaviorSanitizer
[group('sanitizers')]
[group('validation')]
undefined-behavior-sanitizer:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    bash Scripts/run-sanitizer-tests.sh undefined

# run three deterministic same-host XPC request/reply iterations
[group('transport')]
[group('validation')]
xpc-integration:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    bash Scripts/run-xpc-integration.sh

# run all bounded standard and validation targets
[group('aggregates')]
all: all-standard all-validation

# run both standard unit-test configurations
[group('aggregates')]
[group('standard')]
all-standard: debug release

# run every sanitizer independently
[group('aggregates')]
[group('sanitizers')]
all-sanitizers: address-sanitizer thread-sanitizer undefined-behavior-sanitizer

# run the bounded local/CI validation set
[group('aggregates')]
[group('validation')]
all-validation: recipe-contracts all-sanitizers fuzz-smoke hostile-input xpc-integration
