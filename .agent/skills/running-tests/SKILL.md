---
name: running-tests
description: Run the ruby-bindgen test suites — all of them, or a single named test. Read-only — does not regenerate expected output. Use whenever you need to execute tests or check for regressions. To refresh golden files in test/bindings/cpp/, use the update-expected-output skill instead.
---

# Running ruby-bindgen Tests

The repo follows the `*_test.rb` convention. There is no required ordering
between test files — `cmake_test` reads the **committed** `*-rb.cpp` golden
files in `test/bindings/cpp/`, not output freshly produced by `rice_test`.
CI runs them all in one minitest process and passes.

## Run all tests

```bash
bundle exec rake test
```

This is what CI runs. Do **not** try `ruby -Ilib -Itest test/*_test.rb` —
Ruby only loads the first positional arg as a script (the rest become
`ARGV`), so the glob silently runs nothing and reports "0 runs". Use rake
or invoke each file individually.

## Run a specific test

```bash
bundle exec ruby -Ilib -Itest test/rice_test.rb --name test_classes
```

## Updating expected output

If a test fails because the generator output legitimately changed, do not
hand-edit files in `test/bindings/cpp/`. Use the
[update-expected-output](../update-expected-output/SKILL.md) skill.
