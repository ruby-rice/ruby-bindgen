---
name: update-expected-output
description: Regenerate the golden expected-output files under test/bindings/ by re-running the relevant tests with UPDATE_EXPECTED=1 (rice_test and cmake_test write to test/bindings/cpp/, ffi_test writes to test/bindings/c/). Use only after an intentional generator change, and only after the full test suite has been run to check for regressions. Never hand-edit files in test/bindings/.
---

# Update Expected Test Output

This skill regenerates the golden binding fixtures under `test/bindings/`
(`cpp/` for rice + cmake, `c/` for ffi). It is destructive — it overwrites
whatever is on disk with whatever the generator currently emits. Treat it
as a write operation that requires a clean baseline first.

## Hard rules

- **Run the full suite first.** Before using `UPDATE_EXPECTED=1`, run every
  test (see [running-tests](../running-tests/SKILL.md)) and read the
  failures. You must understand which diffs are intended before you let the
  tool overwrite them. Never blindly regenerate.
- **NEVER manually edit files in `test/bindings/cpp/`.** They are golden
  output. Always go through `UPDATE_EXPECTED=1`.

## Which tests honor `UPDATE_EXPECTED`

Three test files write golden output via `validate_result`:

- `test/rice_test.rb` — Rice C++ binding sources → `test/bindings/cpp/`
- `test/cmake_test.rb` — CMake build files → `test/bindings/cpp/`
- `test/ffi_test.rb` — FFI Ruby binding sources → `test/bindings/c/`

Other `*_test.rb` files don't have golden fixtures and are unaffected by
`UPDATE_EXPECTED`.

## Commands

```bash
UPDATE_EXPECTED=1 bundle exec ruby -Ilib -Itest test/rice_test.rb
UPDATE_EXPECTED=1 bundle exec ruby -Ilib -Itest test/cmake_test.rb
UPDATE_EXPECTED=1 bundle exec ruby -Ilib -Itest test/ffi_test.rb
```

Order between these doesn't matter — each test reads only the committed
inputs it needs, not the output of the others.

## After regenerating

Diff the result (`git diff test/bindings/`) and confirm every change is
something you intended. Unexpected churn means the generator change had a
broader effect than planned — investigate before committing.
