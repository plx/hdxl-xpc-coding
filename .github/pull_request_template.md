# Pull request

## Linked work

Closes #

Dependencies (issues or pull requests that had to land first):

## Summary

Describe the focused change and why this is the smallest maintainable solution.

## Regression-first evidence

Provide the failing-before revision, test or command, and observed failure. For
documentation-only or otherwise non-regression work, explain why this does not
apply.

## Validation

List exact commands, toolchain, and results. Include hosted or clean-clone
evidence when relevant.

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ...
```

## Compatibility and release impact

- Public Swift source API:
- XPC object representation and coordinated deployment:
- Toolchain or platform support:
- `CHANGELOG.md` entry, including why none is needed:
- Migration or public documentation:

For a performance-sensitive change, link same-machine release benchmark
reports and identify both measured revisions and the shared harness revision.

## Checklist

- [ ] I used Xcode 26.6 (build 17F113) and Apple Swift 6.3.3 on arm64.
- [ ] I linked the closing issue and every dependency.
- [ ] I added or identified evidence that fails before the fix and passes now,
  or explained why it is not applicable.
- [ ] I ran the relevant canonical local checks and recorded their exact
  results.
- [ ] The test run reports zero known issues or expected failures.
- [ ] I updated public API documentation, the API baseline, the representation
  contract, same-build fixtures, migration guidance, and the changelog wherever
  this change requires them.
- [ ] I included no vulnerability details, credentials, production payloads,
  or other sensitive data.
