EMOJI_REPORTER := "emoji"
GITHUB_ACTIONS_REPORTER := "github-actions-logging"
RELATIVE_PATH := "relative_path"
SUMMARY_REPORTER := "summary"
XCODE_REPORTER := "xcode"


# invokes swiftlint with a single rule
[private]
_swiftlint-single-rule rule reporter target:
    -swiftlint lint --quiet --reporter={{reporter}} --only-rule={{rule}} {{target}}

# invokes swiftlint
[private]
_swiftlint reporter target:
    -swiftlint lint --quiet --strict --reporter={{reporter}} {{target}}

# invokes swiftlint with a specific configuration-file
[private]
_swiftlint-with-configuration configuration reporter target:
    -swiftlint lint --quiet --strict --reporter={{reporter}} --configuration={{configuration}} {{target}}
