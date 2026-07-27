import 'swiftlint.just'

set quiet

[private]
default:
    @just --list todos --unsorted

# invokes a blocking TODO/FIXME check
[private]
invoke-todo-checker reporter target: (_swiftlint-single-rule 'todo' reporter target)

# checks for TODOs and FIXMEs (specific file)
[group('check')]
check-file file reporter=EMOJI_REPORTER: (invoke-todo-checker reporter file)

# checks for TODOs and FIXMEs (sources)
[group('check')]
check-sources reporter=EMOJI_REPORTER: (invoke-todo-checker reporter justfile_directory() / 'Sources')

# checks for TODOs and FIXMEs (tests)
[group('check')]
check-tests reporter=EMOJI_REPORTER: (invoke-todo-checker reporter justfile_directory() / 'Tests')

# checks for TODOs and FIXMEs (all)
[group('check')]
check-all reporter=EMOJI_REPORTER: (check-sources reporter) (check-tests reporter)

# invokes a nonblocking TODO/FIXME summary
[private]
invoke-todo-summarizer target: (_swiftlint-single-rule-summary 'todo' SUMMARY_REPORTER target)

# summarizes/counts TODOs and FIXMEs (specific file)
[group('summarize')]
summarize-file file: (invoke-todo-summarizer file)

# summarizes TODOs and FIXMEs (sources; findings do not fail)
[group('summarize')]
summarize-sources: (invoke-todo-summarizer justfile_directory() / 'Sources')

# summarizes TODOs and FIXMEs (tests; findings do not fail)
[group('summarize')]
summarize-tests: (invoke-todo-summarizer justfile_directory() / 'Tests')

# summarizes TODOs and FIXMEs (all; findings do not fail)
[group('summarize')]
summarize-all: summarize-sources summarize-tests
