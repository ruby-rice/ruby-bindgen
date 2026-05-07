---
name: bug-fix-workflow
description: Test-first workflow and rules for fixing bugs in ruby-bindgen, including how to add coverage, the no-mocks policy, the no-Rice-workarounds policy, and where to put typedef-related test cases. Use whenever fixing a bug, adding a regression test, or before changing generator behavior.
---

# Bug Fix Workflow

Every change to ruby-bindgen behavior follows the same loop: reproduce, cover,
fix, verify.

## Test-first

**Every bug fix MUST include test coverage.** Write a failing test FIRST, then
implement the fix.

1. Add (or extend) a test case in the appropriate header under
   `test/headers/cpp/`.
2. Run the targeted test and confirm it fails for the right reason.
3. Implement the fix in the generator.
4. Run the full suite via the
   [running-tests](../running-tests/SKILL.md) skill to confirm no
   regressions, then regenerate the expected output via the
   [update-expected-output](../update-expected-output/SKILL.md) skill.

## Hard rules

- **NEVER workaround Rice bugs in ruby-bindgen.** If the root cause is in
  Rice, report it so Rice can be fixed instead of teaching ruby-bindgen to
  skip or special-case around it.
- **Mocks are NEVER allowed in tests.** All tests must use real headers and
  real generator output.

## Typedef-related issues

Use `test/headers/cpp/cross_file_base.hpp` and
`test/headers/cpp/cross_file_derived.hpp` for any cross-file typedef
reproduction or regression test.

## One commit per fix

Do not batch multiple unrelated fixes into a single commit. Do not add
`Co-Authored-By` or any other author attribution to commit messages.
