import 'swiftlint.just'

set quiet

[private]
default:
    @just --list docs --unsorted

[group('generate')]
generate-documentation destination:
    # generates documentation
    swift package --allow-writing-to-directory {{destination}} generate-documentation \
        --enable-experimental-combined-documentation \
        --output-path {{destination}} \

# invokes doc-check command
[private]
invoke-doc-checker reporter target: (_swiftlint-single-rule 'missing_docs' reporter target)

# checks documentation (specific file)
[group('check')]
check-file file reporter=EMOJI_REPORTER: (invoke-doc-checker reporter file)

# checks documentation (sources)
[group('check')]
check-sources reporter=EMOJI_REPORTER: (invoke-doc-checker reporter justfile_directory() / 'Sources')

# checks documentation (all)
[group('check')]
check-all reporter=EMOJI_REPORTER: (check-sources reporter)

# invokes doc-check command
[private]
invoke-doc-summarizer target: (_swiftlint-single-rule 'missing_docs' SUMMARY_REPORTER target)

# summarizes documentation status (single file)
[group('summarize')]
summary-check-file file: (invoke-doc-summarizer file)

# summarizes documentation status (sources)
[group('summarize')]
summary-check-sources: (invoke-doc-summarizer justfile_directory() / 'Sources')

# summarizes documentation status (all sources)
[group('summarize')]
summary-check-all: summary-check-sources
