set quiet

[private]
default:
  @just --list test --unsorted

# run all tests (Debug configuration)
[group('debug')]
[group('standard')]
debug:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    swift test -q

# run all tests (Debug configuration)
[group('debug')]
[group('validation')]
debug-with-validation:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    swift test -q -Xswiftc "-DHEAVY_VALIDATION"

# run all tests (Release configuration)
[group('release')]
[group('standard')]
release:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    swift test -q -c release

# run all tests (Release configuration)
[group('release')]
[group('validation')]
release-with-validation:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    swift test -q -c release -Xswiftc "-DHEAVY_VALIDATION"

# run the bounded deterministic fuzzing smoke campaign
[group('fuzzing')]
[group('standard')]
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

# prove the audited defects reproduce at 813c52e and are absent today
[group('regression')]
baseline-evidence:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    bash Scripts/run-baseline-evidence.sh

# run all tests (all configurations)
[group('aggregates')]
all: debug release debug-with-validation release-with-validation

# run all tests (all configurations, standard)
[group('aggregates')]
[group('standard')]
all-standard: debug release

# run all tests (all configurations, standard)
[group('aggregates')]
[group('validation')]
all-validation: debug release

# run all tests (all configurations, standard)
[group('aggregates')]
[group('debug')]
all-debug: debug debug-with-validation

# run all tests (all configurations, standard)
[group('aggregates')]
[group('release')]
all-release: release release-with-validation
