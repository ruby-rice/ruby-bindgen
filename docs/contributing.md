# Contributing

Guidelines for changing `ruby-bindgen` and its generated-output tests.

## Key Files

- `lib/ruby-bindgen/generators/generator.rb` - base class shared by all generators
- `lib/ruby-bindgen/generators/rice/rice.rb` - main AST walker for Rice code generation
- `lib/ruby-bindgen/generators/rice/*.erb` - Rice templates
- `lib/ruby-bindgen/generators/ffi/ffi.rb` - main AST walker for FFI code generation
- `lib/ruby-bindgen/generators/cmake/cmake.rb` - CMake file generator
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

Use the project configs in:
- `/mnt/c/Source/opencv-ruby/ext/rice-bindings.yaml`
- `/mnt/c/Source/opencv-ruby/ext/cmake-bindings.yaml`

Generate with:

```bash
cd /mnt/c/Source/ruby-bindgen
# 1. Generate Rice source files
bundle exec ruby -Ilib bin/ruby-bindgen /mnt/c/Source/opencv-ruby/ext/rice-bindings.yaml
# 2. Generate CMake files
bundle exec ruby -Ilib bin/ruby-bindgen /mnt/c/Source/opencv-ruby/ext/cmake-bindings.yaml
```
