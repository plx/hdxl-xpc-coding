set quiet

[private]
default:
    @just --list format --unsorted

[private]
_verify-swift-format-version:
    @bash {{ quote(justfile_directory() / "Scripts/verify-swift-format-version.sh") }}

# Format all Swift files (sources and tests)
[group('format')]
all: _verify-swift-format-version
    xcrun swift-format format \
        --configuration {{ quote(justfile_directory() / ".swift-format") }} \
        --recursive \
        --parallel \
        --in-place \
        {{ quote(justfile_directory() / "Sources") }} \
        {{ quote(justfile_directory() / "Tests") }}

# Format source files only
[group('format')]
sources: _verify-swift-format-version
    xcrun swift-format format \
        --configuration {{ quote(justfile_directory() / ".swift-format") }} \
        --recursive \
        --parallel \
        --in-place \
        {{ quote(justfile_directory() / "Sources") }}

# Format test files only
[group('format')]
tests: _verify-swift-format-version
    xcrun swift-format format \
        --configuration {{ quote(justfile_directory() / ".swift-format") }} \
        --recursive \
        --parallel \
        --in-place \
        {{ quote(justfile_directory() / "Tests") }}

# Format a specific file
[group('format')]
file file: _verify-swift-format-version
    xcrun swift-format format \
        --configuration {{ quote(justfile_directory() / ".swift-format") }} \
        --in-place \
        {{ quote(file) }}

# Check formatting without modifying files (all)
[group('check')]
check-all:
    bash {{ quote(justfile_directory() / "Scripts/check-swift-format.sh") }}

# Check formatting without modifying files (sources)
[group('check')]
check-sources: _verify-swift-format-version
    xcrun swift-format lint \
        --configuration {{ quote(justfile_directory() / ".swift-format") }} \
        --strict \
        --recursive \
        --parallel \
        {{ quote(justfile_directory() / "Sources") }}

# Check formatting without modifying files (tests)
[group('check')]
check-tests: _verify-swift-format-version
    xcrun swift-format lint \
        --configuration {{ quote(justfile_directory() / ".swift-format") }} \
        --strict \
        --recursive \
        --parallel \
        {{ quote(justfile_directory() / "Tests") }}

# Check formatting for a specific file
[group('check')]
check-file file: _verify-swift-format-version
    xcrun swift-format lint \
        --configuration {{ quote(justfile_directory() / ".swift-format") }} \
        --strict \
        {{ quote(file) }}
