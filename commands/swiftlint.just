EMOJI_REPORTER := "emoji"
GITHUB_ACTIONS_REPORTER := "github-actions-logging"
RELATIVE_PATH := "relative_path"
SUMMARY_REPORTER := "summary"
XCODE_REPORTER := "xcode"

[private]
_verify-swiftlint-version:
    @bash {{ quote(justfile_directory() / "Scripts/verify-swiftlint-version.sh") }}

# invokes a blocking strict SwiftLint check with a single rule
[private]
_swiftlint-single-rule rule reporter target: _verify-swiftlint-version
    swiftlint lint --quiet --strict \
        --config={{ quote(justfile_directory() / ".swiftlint.yml") }} \
        --reporter={{ reporter }} \
        --only-rule={{ rule }} \
        {{ target }}

# invokes a blocking strict SwiftLint check
[private]
_swiftlint reporter target: _verify-swiftlint-version
    swiftlint lint --quiet --strict --reporter={{ reporter }} {{ target }}

# invokes a blocking strict SwiftLint check with a specific configuration file
[private]
_swiftlint-with-configuration configuration reporter target: _verify-swiftlint-version
    swiftlint lint --quiet --strict --reporter={{ reporter }} --configuration={{ configuration }} {{ target }}

# invokes a nonblocking violation summary; tool/configuration failures still fail
[private]
_swiftlint-summary reporter target: _verify-swiftlint-version
    swiftlint lint --quiet --lenient --reporter={{ reporter }} {{ target }}

# invokes a nonblocking single-rule summary; tool/configuration failures still fail
[private]
_swiftlint-single-rule-summary rule reporter target: _verify-swiftlint-version
    swiftlint lint --quiet --lenient \
        --config={{ quote(justfile_directory() / ".swiftlint.yml") }} \
        --reporter={{ reporter }} \
        --only-rule={{ rule }} \
        {{ target }}
