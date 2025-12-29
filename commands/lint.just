import 'swiftlint.just'

set quiet

[private]
default:
    @just --list lint --unsorted

# check (single-file)
[group('check')]
check-file file reporter=EMOJI_REPORTER: (_swiftlint reporter file)

# check (sources)
[group('check')]
check-sources reporter=EMOJI_REPORTER: (_swiftlint reporter justfile_directory() / "Sources")

# check (tests)
[group('check')]
check-tests reporter=EMOJI_REPORTER: (_swiftlint reporter  justfile_directory() / "Tests")

# check (all)
[group('check')]
check-all reporter=EMOJI_REPORTER: (check-sources reporter) (check-tests reporter)

# summarize (single-file)
[group('summarize')]
summarize-file file: (_swiftlint SUMMARY_REPORTER file)

# summarize (sources)
[group('summarize')]
summarize-sources: (_swiftlint SUMMARY_REPORTER justfile_directory() / "Sources")

# summarize (tests)
[group('summarize')]
summarize-tests: (_swiftlint SUMMARY_REPORTER justfile_directory() / "Tests/")

# summarize (all)
[group('summarize')]
summarize-all: summarize-sources summarize-tests
