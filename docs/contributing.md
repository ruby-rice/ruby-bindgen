# Contributing

Guidelines for changing `ruby-bindgen` and its generated-output tests.

## Key Files

- `lib/ruby-bindgen/visitors/rice/rice.rb` - main AST visitor for Rice code generation
- `lib/ruby-bindgen/visitors/rice/*.erb` - Rice templates
- `test/headers/cpp/*.hpp` - C++ input headers for tests
- `test/bindings/cpp/*-rb.cpp` - expected generated output (golden files)

## Run Tests

Run all tests before updating expected files:

```bash
bundle exec ruby -Ilib -Itest test/rice_test.rb
bundle exec ruby -Ilib -Itest test/cmake_test.rb
```

Run one test:

```bash
bundle exec ruby -Ilib -Itest test/rice_test.rb --name test_classes
```

Important:
- Run `cmake_test` after `rice_test` because it scans generated `*-rb.cpp` files.

## Updating Expected Files

Only update expected outputs after all tests pass on current expectations.

```bash
UPDATE_EXPECTED=1 bundle exec ruby -Ilib -Itest test/rice_test.rb
UPDATE_EXPECTED=1 bundle exec ruby -Ilib -Itest test/cmake_test.rb
```

## Test Coverage Requirement

Every bug fix should include test coverage:

- Add or adjust headers in `test/headers/cpp/`
- Update expected generated outputs in `test/bindings/cpp/`

For cross-file typedef issues, use:
- `test/headers/cpp/cross_file_base.hpp`
- `test/headers/cpp/cross_file_derived.hpp`

## Regenerating opencv-ruby Bindings

Use the project config in:
- `/mnt/c/Source/opencv-ruby/ext/bindings.yaml`

Generate with:

```bash
cd /mnt/c/Source/ruby-bindgen
bundle exec ruby -Ilib bin/ruby-bindgen /mnt/c/Source/opencv-ruby/ext/bindings.yaml
```
