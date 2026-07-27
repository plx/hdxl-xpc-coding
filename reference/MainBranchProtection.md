# Main Branch Protection

GitHub repository ruleset
[`Protect main`](https://github.com/plx/hdxl-xpc-coding/rules/11429473)
(ID `11429473`) protects the default branch. Its canonical declarative payload
is [`.github/rulesets/protect-main.json`](../.github/rulesets/protect-main.json).
The checked-in file and the live repository setting must change together.

## Merge policy

Every update to `main` must arrive through a pull request. The pull request
branch must be up to date with `main`, every review conversation must be
resolved, and all 15 required checks must pass. GitHub pins each context to the
GitHub Actions app (integration ID `15368`), so an unrelated app cannot satisfy
a requirement by reporting the same name.

The ruleset requires zero approving reviews. This is deliberate: the
repository currently has one eligible maintainer, so requiring an independent
approval would deadlock the normal workflow. Independent review is still part
of the project remediation and release procedure, but it is a procedural
control until another eligible maintainer exists.

The ruleset permits the repository's merge, squash, and rebase methods. It does
not require linear history, so enabling protection does not silently replace
the existing merge-commit convention. Deleting or force-pushing the default
branch is prohibited.

## Required checks

The required checks are the stable supported-configuration jobs documented in
[Continuous Integration](ContinuousIntegration.md):

- `Supported tests (Xcode 26.6)`;
- `Strict formatting (Xcode 26.6)`;
- `Strict SwiftLint and recipe contracts (Xcode 26.6)`;
- `API documentation (Xcode 26.6)`;
- `Source coverage (Xcode 26.6)`;
- `Same-host XPC request/reply (Xcode 26.6)`;
- `Regression-first baseline evidence (Xcode 26.6)`;
- `Source API stability (Xcode 26.6)`;
- `Deterministic fuzzing smoke (Xcode 26.6)`;
- `Address Sanitizer (Xcode 26.6)`;
- `Undefined Behavior Sanitizer (Xcode 26.6)`;
- `Thread Sanitizer (Xcode 26.6)`;
- `Compile macOS 26 (arm64)`;
- `Compile iOS 26 (arm64)`; and
- `Compile Mac Catalyst 26 (arm64)`.

On 2026-07-27, the maintainer selected these 15 supported-configuration checks
and chose not to require `CodeQL (Actions)`, `CodeQL (Swift, Xcode 26.6)`, or
`Whole-history secret scan` at this time. Those security jobs continue to run
and remain visible advisory evidence. Changing that decision requires a
coordinated update to this document and the canonical ruleset payload.

## Verification and updates

An authenticated maintainer with repository administration access can compare
the live setting with the checked-in policy:

```sh
bash Scripts/verify-main-ruleset.sh
```

The verifier reads the live ruleset, normalizes response-only API fields, and
fails unless the target, active enforcement, empty bypass list, merge policy,
protective rules, and exact set of 15 app-pinned checks match the canonical
payload. It does not mutate repository settings.

After a reviewed policy change, update the existing ruleset rather than
creating a second overlapping rule:

```sh
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  repos/plx/hdxl-xpc-coding/rulesets/11429473 \
  --input .github/rulesets/protect-main.json

bash Scripts/verify-main-ruleset.sh
```

Record the normalized API result and hosted mergeability evidence in the
implementing pull request. A stable job rename must update the workflow and
ruleset in one coordinated change so the repository is never left with a
requirement that no workflow can report.

## Exceptional recovery

The ruleset has no bypass actors. An ordinary maintainer merge therefore
cannot silently bypass a missing or failing check. Repository ownership still
permits deliberate settings administration; use that ability only to recover
from a broken protection configuration, never to ship unverified code.

For exceptional recovery:

1. open an issue that identifies the failure and why the normal pull-request
   path cannot recover;
2. capture the current ruleset response and link the affected run or pull
   request;
3. make the narrowest temporary ruleset edit, recording the API response and
   ruleset history;
4. restore the checked-in policy as soon as recovery is possible; and
5. run `Scripts/verify-main-ruleset.sh` and preserve the successful evidence.

Do not add a standing administrator bypass, bypass a genuine code failure,
force-push `main`, or delete the default branch as part of recovery.
