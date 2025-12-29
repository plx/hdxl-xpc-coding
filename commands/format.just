set quiet

# Use the correct swift-format from homebrew
# SWIFT_FORMAT := "/opt/homebrew/bin/swift-format"

[private]
default:
    @just --list format --unsorted

# Format all Swift files (sources and tests)
[group('format')]
all:
    swift-format format --recursive --parallel --in-place Sources/ Tests/

# Format source files only
[group('format')]
sources:
    swift-format format --recursive --parallel --in-place Sources/

# Format test files only
[group('format')]
tests:
    swift-format format --recursive --parallel --in-place Tests/

# Format a specific file
[group('format')]
file file:
    swift-format format --in-place {{file}}

# Check formatting without modifying files (all)
[group('check')]
check-all:
    swift-format lint --recursive --parallel Sources/ Tests/

# Check formatting without modifying files (sources)
[group('check')]
check-sources:
    swift-format lint --recursive --parallel Sources/

# Check formatting without modifying files (tests)
[group('check')]
check-tests:
    swift-format lint --recursive --parallel Tests/

# Check formatting for a specific file
[group('check')]
check-file file:
    swift-format lint {{file}}
