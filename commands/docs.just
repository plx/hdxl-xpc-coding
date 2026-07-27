import 'swiftlint.just'

set quiet

[private]
default:
    @just --list docs --unsorted

# generates the XPCCoding documentation archive into `destination` (undocumented public declarations and DocC warnings fail)
[group('generate')]
generate-documentation destination:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    bash Scripts/generate-api-documentation.sh {{ quote(destination) }}

# fails when any public declaration in the emitted symbol graphs is undocumented
#
# This is the authoritative completeness gate; `generate-documentation` runs the
# same script against the symbol graphs it has already emitted. The SwiftLint
# `missing_docs` recipes below stay as the fast, file-scoped developer aid.
[group('check')]
check-public-api-completeness:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd {{ justfile_directory() }}
    bash Scripts/verify-public-documentation.sh

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
check-all reporter=EMOJI_REPORTER: (check-sources reporter) check-public-api-completeness

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
