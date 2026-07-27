#!/usr/bin/env bash

set -euo pipefail

readonly repository="${XPCCODING_GITHUB_REPOSITORY:-plx/hdxl-xpc-coding}"
readonly ruleset_id="11429473"
readonly protected_branch="main"

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly script_directory
repository_root="$(cd -- "${script_directory}/.." && pwd)"
readonly repository_root
readonly expected_ruleset="${repository_root}/.github/rulesets/protect-main.json"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

command -v gh >/dev/null || fail "gh is required to verify the main ruleset."
command -v jq >/dev/null || fail "jq is required to verify the main ruleset."
[[ -f "${expected_ruleset}" ]] || fail \
  "Missing canonical ruleset configuration: ${expected_ruleset}"
gh auth status >/dev/null 2>&1 || fail \
  "Authenticate gh before verifying the main ruleset."

actual="$(
  gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "repos/${repository}/rulesets/${ruleset_id}"
)" || fail "Could not read ruleset ${ruleset_id} from ${repository}."
readonly actual
effective="$(
  gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "repos/${repository}/rules/branches/${protected_branch}"
)" || fail \
  "Could not read the effective rules for ${repository}:${protected_branch}."
readonly effective

# GitHub may add response-only fields, and newer API versions may add optional
# pull-request parameters. Normalize only the declarative contract in the
# checked-in payload while retaining every rule type and every required check.
readonly normalization_definitions='
  def normalized_pull_request_parameters:
    {
      allowed_merge_methods: (.allowed_merge_methods | sort),
      dismiss_stale_reviews_on_push,
      require_code_owner_review,
      require_last_push_approval,
      required_approving_review_count,
      required_review_thread_resolution
    };

  def normalized_status_parameters:
    {
      do_not_enforce_on_create,
      required_status_checks: (
        .required_status_checks
        | map({context, integration_id})
        | sort_by(.context)
      ),
      strict_required_status_checks_policy
    };

  def normalized_rule:
    if .type == "pull_request" then
      {
        type,
        parameters: (.parameters | normalized_pull_request_parameters)
      }
    elif .type == "required_status_checks" then
      {
        type,
        parameters: (.parameters | normalized_status_parameters)
      }
    else
      {type}
    end;

  def normalized_rules:
    map(normalized_rule) | sort_by(.type);
'

readonly normalize_ruleset_filter="${normalization_definitions}
  {
    name,
    target,
    enforcement,
    bypass_actors: (
      (.bypass_actors // [])
      | map({actor_id, actor_type, bypass_mode})
      | sort_by(.actor_type, .actor_id, .bypass_mode)
    ),
    conditions: {
      ref_name: {
        include: (.conditions.ref_name.include | sort),
        exclude: (.conditions.ref_name.exclude | sort)
      }
    },
    rules: (.rules | normalized_rules)
  }
"

expected_normalized="$(
  jq --sort-keys --compact-output \
    "${normalize_ruleset_filter}" \
    "${expected_ruleset}"
)" || fail "Canonical ruleset configuration is not valid JSON."
readonly expected_normalized
actual_normalized="$(
  jq --sort-keys --compact-output "${normalize_ruleset_filter}" <<<"${actual}"
)" || fail "GitHub returned an invalid ruleset response."
readonly actual_normalized

if [[ "${actual_normalized}" != "${expected_normalized}" ]]; then
  printf '%s\n' \
    "error: GitHub ruleset ${ruleset_id} does not match ${expected_ruleset}." \
    "Expected normalized policy:" >&2
  jq . <<<"${expected_normalized}" >&2
  printf '%s\n' "Actual normalized policy:" >&2
  jq . <<<"${actual_normalized}" >&2
  exit 1
fi

expected_effective="$(
  jq --sort-keys --compact-output \
    "${normalization_definitions} .rules | normalized_rules" \
    "${expected_ruleset}"
)" || fail "Could not normalize the canonical effective rules."
readonly expected_effective
actual_effective="$(
  jq --sort-keys --compact-output \
    "${normalization_definitions} normalized_rules" \
    <<<"${effective}"
)" || fail "GitHub returned invalid effective branch rules."
readonly actual_effective

if [[ "${actual_effective}" != "${expected_effective}" ]]; then
  printf '%s\n' \
    "error: Effective rules for ${repository}:${protected_branch} do not match the canonical ruleset." \
    "Expected normalized effective rules:" >&2
  jq . <<<"${expected_effective}" >&2
  printf '%s\n' "Actual normalized effective rules:" >&2
  jq . <<<"${actual_effective}" >&2
  exit 1
fi

unexpected_rule_sources="$(
  jq --argjson ruleset_id "${ruleset_id}" \
    '[.[] | select(.ruleset_id != $ruleset_id)] | length' \
    <<<"${effective}"
)"
readonly unexpected_rule_sources
[[ "${unexpected_rule_sources}" == "0" ]] || fail \
  "Effective rules include ${unexpected_rule_sources} rule(s) outside canonical ruleset ${ruleset_id}."

required_check_count="$(
  jq '
    [
      .rules[]
      | select(.type == "required_status_checks")
      | .parameters.required_status_checks[]
    ]
    | length
  ' <<<"${actual}"
)"
readonly required_check_count
[[ "${required_check_count}" == "15" ]] || fail \
  "Expected exactly 15 required checks, found ${required_check_count}."

printf '%s\n' \
  "Verified active ruleset ${ruleset_id} and all effective rules for ${repository}:${protected_branch}: pull requests, 15 strict GitHub Actions checks, resolved conversations, and deletion/force-push protection are required with no bypass actors or overlapping rule sources."
