import 'swiftlint.just'

set quiet

[private]
default:
    @just --list docs --unsorted

# generates the XPCCoding documentation archive into `destination` (DocC warnings fail)
[group('generate')]
generate-documentation destination:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    bash Scripts/generate-api-documentation.sh {{ quote(destination) }}

# invokes a blocking missing-documentation check
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

# invokes a nonblocking missing-documentation summary
[private]
invoke-doc-summarizer target: (_swiftlint-single-rule-summary 'missing_docs' SUMMARY_REPORTER target)

# summarizes documentation status (single file; violations do not fail)
[group('summarize')]
summarize-file file: (invoke-doc-summarizer file)

# summarizes documentation status (sources; violations do not fail)
[group('summarize')]
summarize-sources: (invoke-doc-summarizer justfile_directory() / 'Sources')

# summarizes documentation status (all sources; violations do not fail)
[group('summarize')]
summarize-all: summarize-sources
