set quiet

[private]
default:
  @just --list build --unsorted

# build everything (debug, standard)
[group('debug')]
[group('standard')]
debug:
    swift build

# build everything (debug, heavy-validation)
[group('debug')]
[group('validation')]
debug-with-validation:
    swift build -Xswiftc "-DHEAVY_VALIDATION"

# build everything (release, standard)
[group('release')]
[group('standard')]
release:
    swift build -c release

# build everything (release, heavy-validation)
[group('release')]
[group('validation')]
release-with-validation:
    swift build -c release -Xswiftc "-DHEAVY_VALIDATION"

# build all configurations and variants
[group('aggregates')]
all: debug debug-with-validation release release-with-validation

# build all debug variants
[group('aggregates')]
[group('debug')]
all-debug: debug debug-with-validation

# build all release variants
[group('aggregates')]
[group('release')]
all-release: release release-with-validation

# build all standard variants
[group('aggregates')]
[group('standard')]
all-standard: debug release

# build all validation variants
[group('aggregates')]
[group('validation')]
all-with-validation: debug-with-validation release-with-validation
