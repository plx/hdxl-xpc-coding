# XPCCoding Production-Readiness Remediation Goal

**Program:** [#59](https://github.com/plx/hdxl-xpc-coding/issues/59)\
**Planning PR:** [#61](https://github.com/plx/hdxl-xpc-coding/pull/61)\
**Audited baseline:** `813c52e`\
**Initial disposition:** `NO-GO` for production release

## Copy-paste goal

After PR #61 has merged, start a new Codex session from a clean, current
`main` checkout and submit:

```text
/goal Complete the work in `reference/ProductionReadinessRemediationGoal.md`.
```

This is an execution goal, not a request to edit or summarize this document.
The goal remains active until the terminal completion criteria below are met.
Open pull requests, green checks on unmerged commits, or a completed audit that
does not reach `GO` are progress, not completion.

## Required outcome

Complete the live production-readiness program rooted at #59, including every
current or subsequently discovered issue carrying
`program:production-readiness`. Execute the program as an ordered sequence of
small, reviewable changes:

- work on one selected remediation issue at a time;
- base independent work on current `main`;
- use a shallow, explicitly documented PR stack only when already-selected or
  pre-existing work must be reconciled with an unmerged prerequisite;
- merge prerequisites before dependent work;
- close each ordinary remediation leaf through its own focused merged PR,
  except for a maintainer-resolved not-planned design outcome recorded under
  the decision checkpoint rules;
- complete and validate component epics
  [#53](https://github.com/plx/hdxl-xpc-coding/issues/53) through
  [#58](https://github.com/plx/hdxl-xpc-coding/issues/58);
- include pre-audit Swift Package Index preparation
  [#60](https://github.com/plx/hdxl-xpc-coding/issues/60) in the immutable
  candidate;
- execute the independent audit
  [#52](https://github.com/plx/hdxl-xpc-coding/issues/52) and close it only
  after an unconditional `GO`;
- publish exactly that audited commit through
  [#51](https://github.com/plx/hdxl-xpc-coding/issues/51), without changing
  repository files; and
- close #59 only after every native child and every later program finding is
  complete.

Do not hard-code a release version in this runbook. The version and stability
policy established by issue #47 and accepted by the final audit control the
published semantic tag.

## Fixed support policy and scope

The production envelope is intentionally narrow:

- Swift **6.3 only**;
- macOS **26 or newer**;
- iOS **26 or newer**;
- Mac Catalyst **26 or newer**;
- Swift Package Manager distribution; and
- Apple XPC representation and transport.

Do not expand the toolchain or platform matrix during this goal. Passing with a
newer Swift version does not establish Swift 6.3 support, and this program does
not promise support for earlier or later Swift versions.

The static documentation website and landing page are out of scope. The
following remain in scope because they are part of the package or its release
contract:

- source, tests, fixtures, benchmarks, and XPC integration harnesses;
- `Package.swift` and Swift Package Index metadata;
- README and public API documentation;
- CI, formatting, linting, coverage, and sanitizer enforcement;
- licensing, attribution, security policy, and repository controls; and
- semantic tagging, GitHub Release publication, and Swift Package Index
  submission.

This repository vends a Swift library. Do not introduce Cargo, crates.io,
Homebrew, CLI-distribution, or unrelated website work by analogy with another
project.

## Scope and authority

Invoking this goal authorizes the normal in-repository work needed to complete
the program:

- inspect and modify files in this repository;
- run local and GitHub-hosted validation;
- create issue-specific branches, commits, and draft pull requests;
- update those pull requests in response to review and CI;
- create self-contained issues for genuinely new production-readiness
  findings;
- maintain the program's semantic labels, native parent relationships, and
  native blockers when new evidence requires it;
- merge an ordinary remediation PR after every prerequisite, required review,
  and required check is satisfied; and
- remove a merged ticket branch when no descendant stack needs it.

That authority does **not** permit:

- bypassing branch protection, required review, or a failing check;
- force-merging, using an administrator override, or weakening a gate to make
  progress;
- changing a public API, wire, concurrency, error, or compatibility contract
  by convenience when the selected ticket leaves materially different valid
  outcomes;
- inventing legal conclusions, protected-setting attestations, credentials,
  owners, platform results, or audit evidence;
- exposing credentials or committing sensitive XPC payloads or private audit
  evidence;
- publishing a tag, GitHub Release, or Swift Package Index submission before
  the publication checkpoint below; or
- writing to another repository or service outside the confirmed publication
  scope.

Do not stop merely because the program spans many turns or compactions.
Persist through ordinary implementation, validation, review, merge, and stack
maintenance. Stop for user direction only at a defined checkpoint or a genuine
unresolved blocker.

## Preconditions

Before selecting the first remediation issue:

1. Confirm planning PR #61 has merged. It installs the historical audit, issue
   program, final-audit procedure, and this runbook. Do not build remediation
   branches on its unmerged branch.
2. Start from a clean checkout of current remote `main`. Preserve unrelated
   user changes and use a separate worktree when necessary.
3. Confirm:

   ```sh
   gh auth status
   gh repo view --json nameWithOwner,defaultBranchRef,url
   git status --short --branch
   git fetch origin
   git rev-parse HEAD
   git rev-parse origin/main
   swift --version
   xcodebuild -version
   ```

4. Require repository identity `plx/hdxl-xpc-coding`, default branch `main`,
   appropriate write access, and the exact Swift 6.3 toolchain for release
   evidence.
5. Reconcile live GitHub state with the committed
   [issue-program index](ProductionReadinessIssueProgram.md):

   - every program issue has the required semantic labels;
   - ordinary component leaves have exactly one native parent;
   - native `blocked by` relationships remain acyclic;
   - component epics #53 through #58, audit #52, publication #51, and top-level
     epic #59 retain their intended roles; and
   - any material drift is explained and reflected in the index.

6. Inspect open pull requests for existing work or closing coverage before
   choosing a new ticket.

If PR #61 is unmerged, authentication is unavailable, repository identity is
wrong, or the native dependency state cannot be inspected reliably, report the
condition and wait. Do not substitute a remembered issue order.

## Required guidance

At the beginning of the goal, read:

1. [`AGENTS.md`](../AGENTS.md);
2. the
   [due-diligence report](ProductionReadinessDueDiligence-2026-07-25.md);
3. the [issue-program index](ProductionReadinessIssueProgram.md);
4. the
   [post-remediation audit procedure](PostRemediationProductionReadinessAudit.md);
5. this runbook;
6. top-level epic
   [#59](https://github.com/plx/hdxl-xpc-coding/issues/59); and
7. the full body, comments, native parent, native blockers, linked decisions,
   and prior art for the issue selected in the current loop.

Also read:

- [`ProjectHistory.md`](ProjectHistory.md) when architecture, naming, or
  physical organization is relevant;
- [`EmbeddedNullByteHandling.md`](EmbeddedNullByteHandling.md) for any string,
  key, or embedded-NUL work; and
- contributor, security, release, support, or normative-contract guidance
  added by earlier remediation PRs.

Re-read the selected ticket and relevant shared guidance after compaction,
handoff, a material review change, or a changed dependency graph. Do not rely
on remembered acceptance criteria.

Apply instructions in this order:

1. current user, system, developer, and repository safety instructions;
2. the selected issue's required behavior and acceptance criteria;
3. `AGENTS.md` and current repository conventions;
4. the live native issue graph, issue-program index, and this runbook;
5. the final-audit procedure; and
6. the historical due-diligence report and prior art.

When sources appear to conflict, inspect the current implementation, tests,
issue history, and linked decisions. Resolve the conflict explicitly in the PR
or ask the maintainer when it would materially alter a public contract. Do not
choose the interpretation that merely makes the ticket easiest to close.

The 2026-07-25 due-diligence report is immutable historical evidence about
revision `813c52e`; it is not a substitute for inspecting current `main`.

## Work-selection contract

This repository does not currently contain an automated
production-readiness selector. Live GitHub labels, native parents, native
blockers, issue state, and PR state are authoritative.

At each selection boundary:

1. Finish reconciling any issue already being implemented by this goal. Do not
   abandon a selected issue merely because another one has become ready.
2. Enumerate the open `program:production-readiness` cohort and inspect
   possible closing PRs.
3. Exclude `type:epic` issues and gated orchestration work that has unmet
   children or blockers.
4. A remediation leaf is ready only when:

   - it is open;
   - all native blockers are closed;
   - its parent and labels place it in the program; and
   - it is not already claimed by an active, correctly targeted closing PR.

5. Select from ready leaves by priority: P0, then P1, P2, then P3.
6. If several ready leaves have the same priority, choose the one that directly
   blocks the greatest number of open program issues. If that does not
   distinguish them, choose the lowest issue number as a stable tie-breaker.
7. Before implementing it, re-read the issue and confirm the live graph still
   makes it ready.

Ordinary leaf selection covers the component-remediation leaves, #60, and later
findings. It does not select component epics, #52, #51, or #59. When ordinary
leaf work reaches the relevant boundary:

- validate and close a ready component epic under its gate rules;
- after all six component epics close, execute #52 under its audit rules;
- after #52 closes with `GO`, execute #51 under its publication rules; and
- close #59 last under its final-gate rules.

An open prerequisite PR is not a closed blocker and does not justify selecting
or implementing a new blocked leaf. If already-selected or pre-existing work
becomes stacked because the graph changed, freeze the dependent branch until
the prerequisite merges, then restack it on current `main`. The stack rules
below exist to reconcile that exceptional state, not to bypass readiness.

The issue-program index says parallel work is permitted when blockers allow
it. For this single long-running goal, implementation remains serial:
subagents may perform bounded research or independent review, and unrelated
human work may proceed, but this goal must not have different agents
implementing several workflow issues at once.

If no ready issue exists:

- finish review, CI, or merge work for an already claimed issue;
- inspect whether a closing PR has made the queue temporarily covered but not
  complete;
- diagnose stale or invalid native relationships without changing them merely
  to manufacture preferred work; and
- wait when all remaining work genuinely depends on external review, a
  maintainer decision, or unavailable infrastructure.

## Non-negotiable workflow rules

1. **One selected implementation issue at a time.** A ticket remains selected
   through implementation, review, CI, and merge unless it reaches a genuine
   blocker and another ready issue can safely progress.
2. **One ordinary remediation leaf per PR.** Split unrelated fixes unless the
   selected ticket itself requires an inseparable change. A design ticket
   explicitly resolved not planned at a maintainer checkpoint is the narrow
   administrative exception; record the decision in the issue and durable
   repository guidance rather than manufacturing a no-op PR.
3. **Target `main`.** Independent branches start from current remote `main`.
   An inherited or pre-existing dependent branch may temporarily contain an
   unmerged prerequisite's commits while it is frozen, but its GitHub PR still
   targets `main`.
4. **Open work is not landed work.** Approval, green CI, a checked box, or an
   open closing PR does not satisfy a native blocker.
5. **Tests prove the defect when applicable.** Add a regression or negative
   control that fails for the intended reason before the fix and passes
   afterward. Preserve the exact command and concise red-before-fix result in
   the PR.
6. **Do not weaken evidence.** Never delete or relax a test, acceptance
   criterion, dependency, label, quality rule, sanitizer, branch rule, or audit
   gate merely to obtain a green result.
7. **Keep public contracts aligned.** Update README, API documentation,
   migration notes, fixtures, and release notes in the same PR whenever the
   selected behavior changes them.
8. **No silent scope absorption.** Give a newly discovered independent defect
   its own self-contained issue and graph metadata unless fixing it is
   necessary to meet the selected ticket's existing criteria.
9. **Preserve the support envelope.** Do not make broader Swift or platform
   compatibility an incidental acceptance criterion.
10. **Treat XPC input as untrusted at decoding boundaries.** Malformed,
    cyclic, deeply nested, oversized, and architecture-different inputs must
    receive the bounded behavior promised by the accepted contract.

## Risk-specific invariants

The following evidence must not be diluted while individual tickets are
implemented:

- a string or key transform described as reversible is bijective over its
  documented domain;
- supported binary decoding does not require accidental pointer alignment;
- decoder depth, graph traversal, and allocation remain within shared,
  documented resource budgets;
- invalid public pointer/count combinations follow one explicit, tested
  contract and never reach libxpc unexpectedly;
- ordinary `Data` has the intended constant-object representation rather than
  per-byte XPC-object amplification;
- Codable container reuse, coding paths, missing-key behavior, user errors,
  and `userInfo` satisfy the accepted public semantics;
- XPC representation changes use the explicit same-host, same-build contract
  with reviewed structural fixtures, without implying versioned,
  architecture-neutral, persistent, or network compatibility;
- transport claims are supported by real cross-process XPC request/reply
  evidence, not only in-memory object round trips;
- concurrency claims compile in an external Swift 6.3 strict-concurrency
  client and have appropriate dynamic evidence;
- performance claims use release builds, recorded hardware and methodology,
  and thresholds chosen before the final measurement; and
- licensing and attribution conclusions cite reviewed provenance rather than
  tool heuristics.

## Pull-request stack contract

The program is a sequence of small PRs, not one giant remediation branch.
New work is not intentionally stacked; the rules below keep an exceptional
pre-existing or graph-change stack shallow and reviewable while it is unwound.

### Starting a branch

- Create every newly selected issue branch from current remote `main`.
- Do not begin a blocked issue from an open prerequisite branch.
- If an already-selected or pre-existing branch later acquires an unmerged
  prerequisite, stop implementation, record its exact ancestry, and keep it
  frozen until the prerequisite merges.
- After that merge, restack the dependent branch on current `main` before
  resuming implementation.
- Use an issue-specific branch name. Never reuse a merged or abandoned ticket
  branch.

Every PR targets `main`. A temporarily stacked PR may show ancestor commits and
diff until its predecessor merges; describe that clearly.

Keep at most one unmerged descendant above a predecessor. Before preparing
another level, merge and restack from the bottom so every open diff remains
reviewable. Revalidate every affected descendant after an ancestry rewrite.

### Stack metadata

Every stacked PR body identifies:

- the immediate predecessor PR, or `none`;
- all earlier PRs whose commits are present;
- required merge order;
- whether tests require the predecessor's code; and
- the exact commit or branch point from which it was created.

Use ordinary `Refs #N` references for related issues. Only the selected
ordinary leaf receives a closing keyword.

### Merge order

- Merge from the bottom upward.
- Never merge a dependent PR while a semantic prerequisite issue is open.
- Require the predecessor to be merged, not merely approved or green.
- After each predecessor merge, update the next PR on current `main`, remove
  already-landed ancestor changes from its diff, resolve conflicts, and rerun
  affected validation.
- Use `--force-with-lease` only when an ancestry rewrite is necessary, only on
  the goal's own verified ticket branch, and only after confirming no other
  work depends on the unpublished head. Never use an unguarded force push.
- Recheck the child PR's base, diff, closing reference, checks, and review state
  after any rebase or base update.

Component, audit, and publication gates begin only when their native
requirements are actually closed.

## The one-issue loop

Repeat this loop for ordinary remediation leaves until the program reaches a
gate boundary. Component epics, #52, #51, and #59 follow their dedicated
sections below wherever those rules differ from the ordinary loop. In
particular, do not apply the ordinary closing-PR template to an audit in
progress, external publication, or an evidence-only epic closure.

### 1. Reconcile live state

Fetch current `main`, inspect the worktree, enumerate open program issues, and
inspect existing PRs. If an issue is already in progress, continue it before
selecting another.

Apply the work-selection contract. If the result appears inconsistent with the
native graph, inspect labels, parentage, blockers, pagination, and closing PRs.
Do not guess or relabel work to obtain a preferred ticket.

### 2. Establish the ticket contract

Read the issue and all linked guidance. Make a working checklist mapping:

- each acceptance criterion to a code, test, documentation, or evidence
  change;
- each requested validation command to a planned run;
- each native dependency to a closed issue or named stack predecessor;
- each non-goal to a scope boundary;
- every API, wire, compatibility, performance, or release implication; and
- every decision that needs maintainer input.

Inspect current source and tests rather than assuming the historical report
still describes `main`. Search for overlapping PRs and linked prior art.

### 3. Capture the before state

Before implementation:

- reproduce the defect or missing control on the appropriate vulnerable
  revision when the ticket requires it;
- add or design the regression that fails for the intended reason;
- record the exact command, environment, exit status, and concise result;
- distinguish environmental failure from evidence of the defect; and
- explain when red-before-fix evidence is genuinely inapplicable, such as a
  pure contract, documentation, legal, or repository-settings decision.

Do not leave the final PR red. Use a disposable worktree, subprocess fixture,
or reversible local step when old-behavior evidence would otherwise disrupt
the implementation branch.

For a crash, abort, stack-exhaustion, sanitizer, or resource-exhaustion
reproducer, isolate the old behavior in a subprocess with finite wall-clock and
memory limits. Do not let an expected historical failure terminate or hang the
test runner.

### 4. Implement only the selected issue

Make the smallest complete change that satisfies the ticket. Preserve
unrelated user work and follow the accepted architecture and formatting.
Prefer bounded, explicit failure for hostile inputs. Update every affected
user-facing or maintainer contract in the same PR.

If implementation reveals a separate defect:

1. determine whether it is required to satisfy the selected ticket;
2. if not, create a self-contained issue with:

   - observable problem and impact;
   - reproduction and relevant repository state;
   - required direction and non-goals;
   - failing-before-fix test or negative-control expectations;
   - exact validation and acceptance criteria;
   - the `program:production-readiness` label, one `type:*`, one
     `priority:*`, one `effort:*`, and relevant `domain:*`, `component:*`,
     release, and target labels;
   - exactly one native component parent from #53 through #58; and
   - native blockers only for real semantic prerequisites;

3. reopen the affected component epic if it had closed and ensure the native
   graph prevents #52 and #51 from proceeding until that component is
   revalidated;
4. update the issue-program index when hierarchy or intended order changes
   materially; and
5. return to the selected ticket without hiding the new finding in its PR.

### 5. Validate before publication

Run every ticket-specific command and proportionate repository-wide checks.
The ordinary Swift baseline is:

```sh
swift --version
xcodebuild -version
swift package dump-package
swift build -Xswiftc -warnings-as-errors
swift test
swift test -c release
```

Release evidence must use Swift 6.3. Add the platform compile, formatter,
linter, documentation, API, coverage, sanitizer, fuzz/property, subprocess,
cross-process XPC, benchmark, or negative-control commands required by the
ticket.

Issues #39 through #45 harden repository quality commands and CI. Until their
fixes land, do not treat an aggregate `just` result as proof when a known
recipe suppresses an underlying failure or does not exercise the claimed
variant. Run the underlying tool directly and record the limitation. After
those issues land, use the canonical aggregate command they establish in
addition to ticket-specific checks.

Do not claim that an unavailable toolchain, OS, simulator, sanitizer, service
topology, or protected setting passed. Record the limitation and use
appropriate CI or request the required environment.

Inspect the final diff for unrelated changes, generated artifacts, credentials,
private payloads, debugging output, stale documentation, and accidental public
API or wire changes.

### 6. Commit and open one draft PR

Commit only the selected ticket's files. Push its issue-specific branch and
open a draft PR targeting `main`.

For an ordinary remediation leaf, use this body structure:

```markdown
Closes #<selected-issue>

## Scope

<What this ticket changes and why>

## Dependencies and stack

- Immediate predecessor: <PR URL or none>
- Earlier included PRs: <URLs or none>
- Required merge order: <bottom to top>
- Branch point: <commit>

## Red-before-fix evidence

<Command and concise failing result, or why not applicable>

## Validation

- `<command>` — <result>

## Acceptance criteria

<Map every issue criterion to evidence in this PR>

## API, wire, and support impact

<No change, or the accepted contract and migration impact>

## Residual risks

<None, or explicit limitations and follow-up issue links>
```

The PR body should contain one closing keyword for the selected ordinary leaf
and none for another program issue. Do not put closing keywords in commit
messages, stack metadata, review comments, or external artifacts. Use
non-closing references there.

### 7. Verify the GitHub relationship

After opening or updating the PR, wait for GitHub indexing and inspect:

```sh
gh pr view <pr-number> \
  --json baseRefName,headRefName,closingIssuesReferences,isDraft,state
```

Require:

- state `OPEN`;
- base `main`;
- draft status until ready for review; and
- exactly the selected ordinary leaf in `closingIssuesReferences`.

Confirm the issue itself remains open while the PR is open. Correct linkage
before selecting additional work; do not close the issue manually as a
substitute for a malformed PR relationship.

### 8. Complete review and CI

Monitor required checks. Read all review comments and inline threads,
implement actionable corrections, rerun affected checks, and keep the PR body
and stack metadata current.

Mark the PR ready only when:

- the final diff is limited to the selected ticket;
- every stack predecessor has merged;
- the branch is updated on current `main` and ancestor-only changes no longer
  appear in its diff;
- every acceptance criterion has evidence;
- local and required hosted checks pass on the final head;
- the closing relationship remains exact; and
- every unresolved review concern is fixed or answered with a concrete
  rationale.

Do not dismiss a failing check as flaky without reproducing and documenting
the evidence. Do not merge around a review request.

### 9. Merge safely

Merge an ordinary remediation PR only when:

- every semantic and stack prerequisite has merged;
- branch protection and required approvals are satisfied;
- all required checks are green on the final head;
- the final PR targets `main` and closes exactly one ordinary program leaf;
  and
- no decision or release checkpoint applies.

If GitHub does not require human approval, routine implementation PRs may merge
after all checks pass and a separate person, agent, or fresh review context has
performed an independent diff-and-acceptance review with no unresolved
blocker. Public-contract decisions, legal judgments, protected-setting
attestations, the independent audit verdict, and publication remain subject to
their explicit checkpoints.

Use the configured merge method and never use an administrator bypass. After
merge:

1. allow bounded time for GitHub indexing;
2. verify the merged PR closed the selected issue;
3. inspect its closing relationship or timeline;
4. if GitHub does not apply the intended closure, do not conceal the problem
   with an unexplained state change—diagnose it and request direction when
   necessary;
5. update and revalidate the next descendant PR, if one exists;
6. remove the merged branch when no descendant needs it; and
7. return to live work selection.

## Decision and administrative checkpoints

The dependency graph schedules work; it does not make maintainer, legal,
credentialed, or ownership decisions.

Research the alternatives and propose a concrete direction, but request
maintainer approval before landing a materially unresolved choice involving:

- unsafe pointer/count behavior and public preconditions;
- error identity and taxonomy;
- codec configuration ownership, default construction, or concurrency
  guarantees;
- numeric mappings, application-versus-library transport ownership, or the
  supported XPC representation boundary;
- public API resilience or `@inlinable` policy;
- licensing, attribution, or upstream Runtime Library Exception treatment;
- semantic-versioning and release compatibility policy; or
- security, branch-protection, signing, and publishing controls.

Issues #22, #28, #31, #35, #47, #48, and #50 are especially likely to need
such judgment or credentialed evidence. The selected ticket and then-current
implementation remain authoritative; this list is not exhaustive.

Never invent a legal conclusion, account setting, credential, release signer,
reviewer, or platform result. A decision checkpoint pauses the selected loop;
it does not end the goal. Resume once the decision or owner action is recorded.

## Component gates: #53 through #58

The six component epics are aggregate evidence gates, not implementation
shortcuts.

Close a component epic only after:

- all of its native children are closed;
- all cross-component native blockers relevant to its acceptance are closed;
- combined validation is rerun against current `main`;
- interactions among its leaf fixes are reviewed; and
- durable evidence maps the epic's completion criteria to merged PRs, commands,
  and retained artifacts.

Do not add an epic closing keyword to an ordinary leaf PR. If a meaningful
repository evidence artifact is required, use a focused evidence PR. If no
repository change is justified, record the aggregate evidence on the issue and
close it only after the evidence is independently checked; do not manufacture
a no-op PR.

If a new finding invalidates a closed component epic:

1. reopen the epic;
2. attach the new issue under the correct component parent;
3. add real native blockers;
4. block or invalidate downstream audit/publication work;
5. remediate the finding; and
6. rerun and record the component's aggregate validation before closing it
   again.

Never leave a stale closed epic as apparent evidence.

## Immutable candidate and audit gate #52

Issue #52 begins only after every component epic has closed. All
candidate-affecting preparation must already have landed, including:

- source and tests;
- fixtures, benchmarks, and integration harnesses;
- `Package.swift`, dependency resolution, and `.spi.yml` from #60;
- README, API documentation, changelog, and migration notes;
- CI and release workflows; and
- security, licensing, and repository policy files.

Freeze and identify one exact commit. Run #52 from a fresh checkout and a fresh
session or context. Prefer an auditor who did not implement most remediation.
The remediation context may hand off facts and artifact locations, but it must
not manufacture the verdict.

Follow every applicable section of
[PostRemediationProductionReadinessAudit.md](PostRemediationProductionReadinessAudit.md).
Commit a dated audit report tied to the candidate and preserve reproducible
evidence.

The verdict rules are strict:

- only an unconditional `GO` for the exact immutable candidate may close #52;
- `CONDITIONAL GO` and `NO-GO` reports must leave #52 open;
- every substantive new finding receives a separate
  `program:production-readiness` issue, the complete semantic labels, one
  native component parent, and real native blockers;
- reopen the affected component epic so its existing native relationship keeps
  #52 and #51 blocked until revalidation;
- do not repair findings inside the audit-report PR;
- after remediation, freeze a new candidate and rerun every affected audit
  phase; and
- add `Closes #52` to the audit-report PR only after its committed report
  contains the valid `GO` and all required evidence.

An audit-in-progress, `CONDITIONAL GO`, or `NO-GO` report PR uses only
`Refs #52` and must have no program issue in its closing relationships. Only
the final report PR for a valid `GO` may close exactly #52. Issue #51 uses no
repository PR at all, and #59 closes from its reviewed final evidence unless a
meaningful repository artifact independently justifies a PR.

After #52 closes, no repository commit of any kind may land on `main` before
the audited candidate is tagged and its GitHub Release is published. This
total freeze satisfies #51's requirement that no intervening repository commit
separate audit approval from tagging. If any change becomes necessary, stop
publication, reopen #52 and every affected component gate, land and validate
the change, freeze a new candidate, and run a fresh independent audit. The
prior `GO` does not authorize a changed repository state.

## Publication gate #51

Issue #51 is selected only after #52 has closed with `GO` and #60's metadata is
part of the audited candidate.

This is the deliberate exception to the ordinary closing-PR rule. It performs
external publication but must make **no repository-file change**, because any
such change would make the published commit differ from the audited candidate.
Do not manufacture a no-op PR.

Immediately before irreversible publication, present the maintainer with:

- the exact audited candidate SHA;
- the dated unconditional `GO` report;
- the intended semantic version and annotated tag;
- the proposed GitHub Release notes;
- the already-audited `.spi.yml` and canonical repository URL;
- the final non-mutating Swift 6.3 release verification;
- the intended signing or protected-release mechanism; and
- every remaining limitation or risk.

Obtain explicit maintainer confirmation unless a protected release environment
itself supplies required human approval for this exact candidate. The broad
goal invocation does not waive this final checkpoint.

After approval:

1. verify the clean checkout still identifies the exact audited SHA;
2. create an immutable annotated, preferably signed semantic tag at that SHA;
3. publish the GitHub Release for the same tag;
4. submit the canonical repository to Swift Package Index using the audited
   metadata;
5. wait for and inspect the live package and API-documentation results;
6. verify every artifact states only Swift 6.3 and Apple platform 26+ support;
7. record tag, release, SHA, audit, Package Index, build, and documentation
   links on #51; and
8. close #51 only after its acceptance criteria and external evidence are
   complete.

If current Package Index requirements demand a source or metadata change, do
not move a tag or patch the audited candidate. Stop, reopen #60, #52, and every
affected component gate, create a new candidate, and repeat the invalidated
audit and publication steps.

If an external step fails after an immutable tag or release exists, preserve
that artifact, diagnose the failure, and request direction. Never move,
replace, or reuse the tag for a repair commit.

## Final program gate #59

Top-level epic #59 closes last. Before closing it, verify:

- all native children, including #52 and #51, are closed;
- no later `program:production-readiness` finding remains open;
- no remediation or audit PR/stack remains open;
- the published tag, GitHub Release, `GO` report, and Swift Package Index entry
  identify the same candidate;
- component and final-gate evidence remains valid; and
- the issue's program-level release checklist is complete.

Record a concise final evidence summary on #59 and obtain independent review.
If no repository change is required, close the epic from that evidence rather
than manufacturing a no-op PR.

## Continuity across turns and compaction

GitHub and committed files are the durable source of truth. Never rely only on
conversation memory or an untracked note.

At every handoff or resumed turn:

1. re-read this runbook and the selected ticket;
2. inspect `git status`, current branch, upstream, and worktree ownership;
3. inspect the selected issue, native blockers, and current PR;
4. verify GitHub state rather than assuming it remained unchanged;
5. report:

   - selected issue;
   - branch and PR URL;
   - blocker and stack-predecessor state;
   - last validation result;
   - review and CI state; and
   - exact next action;

6. continue the current one-issue loop before selecting more work.

Keep every unfinished change on a named, pushed ticket branch or in a clearly
reported local worktree. Do not leave critical progress only in temporary
files.

## Stop and ask conditions

Pause for user or maintainer direction when:

- the selected ticket contains materially different valid public-contract
  outcomes and no decision is recorded;
- satisfying it requires a destructive migration or external state not
  authorized here;
- branch protection, required review, or a genuine failing check cannot be
  satisfied without an override;
- the native dependency graph cannot be verified or appears incorrect in a
  way that would alter program scope;
- a required credential, Swift 6.3/platform environment, repository setting,
  reviewer, signer, or owner is unavailable;
- a legal or provenance conclusion requires qualified judgment;
- issue #51 reaches the irreversible publication checkpoint; or
- publication requires an unplanned repository or service.

Do not ask merely because a ticket is difficult, a shallow stack needs
restacking, CI takes time, or the program is long.

## Terminal completion criteria

Mark the goal complete only when all of the following are true:

- the live `program:production-readiness` cohort contains no open issue,
  including later findings and top-level #59;
- every ordinary remediation leaf either closed through its dedicated merged
  PR with ticket-specific evidence or explicitly resolved not planned at a
  maintainer decision checkpoint with durable issue and repository evidence;
- every component epic has valid aggregate evidence;
- no remediation, audit, or intentional stack PR remains open;
- issue #52 records unconditional `GO` for one exact immutable candidate;
- issue #51 has published that exact SHA as an immutable annotated semantic
  tag and matching GitHub Release;
- Swift Package Index lists the canonical repository and its available build
  and API-documentation results have been inspected;
- the audit report, tag, release, and Package Index evidence all identify the
  same candidate and intentional support envelope;
- a clean checkout of the released candidate passes the required Swift 6.3
  release verification; and
- the final response links the issues, PRs, audit report, release, package
  listing, and validation evidence needed for another maintainer to reproduce
  the conclusion.

## Provenance

This runbook adapts the operational structure of the
[Agentic Navigation Guide production-readiness remediation goal](https://github.com/plx/agentic-navigation-guide/blob/main/audits/production-readiness-remediation-goal.md)
to XPCCoding's Swift/XPC implementation, live issue graph, support policy,
audit verdicts, and publication path. The rules in this document are
project-specific; behavior from the source repository does not carry over
unless stated here.
