# Code Review Round 4 (2026-03-13)

Comprehensive review of the full codebase. Findings triaged and validated.

## HIGH Severity

### #1 — FIXED: FFI: Missing variadic function support
**File:** `lib/ruby-bindgen/generators/ffi/ffi.rb:219`

`visit_function` didn't handle variadic functions. FFI supports them via `:varargs` as the last parameter type, but the generator silently dropped the `...`. Now appends `:varargs` when `cursor.type.variadic?` is true. Also picked up real-world fixes in the sqlite3 golden file.

### #2 — FFI: Missing parameter type skip checks
**File:** `lib/ruby-bindgen/generators/ffi/ffi.rb:219-246`

`visit_function` only checks if the **return type** references a skipped symbol (line 222) but doesn't check **parameter types**. Rice checks both with `has_skipped_param_type?` and `has_skipped_return_type?`. A function like `void process(SkippedClass& obj)` would generate bindings referencing a type that was skipped.

**Fix:** Add parameter type checking analogous to Rice's `has_skipped_param_type?`.

### #3 — FFI: Incomplete `references_skipped_type?`
**File:** `lib/ruby-bindgen/generators/ffi/ffi.rb:395-401`

FFI's `references_skipped_type?` is much simpler than Rice's `type_references_skipped_symbol?` and is missing:
- Checking **canonical** type (only checks the direct type)
- Recursive **template argument** checking (e.g., `std::vector<SkippedClass>`)
- **Spelling fallback** for dependent types where no declaration exists (now `@symbols.skip_spelling?`)

Rice's version (lines 171-201) handles all these cases. FFI's version will miss skipped types in templates and dependent contexts.

**Fix:** Align with Rice's implementation — check both canonical and non-canonical, recurse into template args, fall back to `@symbols.skip_spelling?`.

## MEDIUM Severity

### #4 — Rice: Operator return type detection uses substring matching
**File:** `lib/ruby-bindgen/generators/rice/rice.rb:1830`

```ruby
elsif result_type.include?("&") && result_type.include?(arg0_type.delete("&").strip)
```

Uses `String#include?` to check if the return type contains the arg0 type (sans reference). This is substring matching — if `arg0_type` is `"const Mat&"`, the cleaned form `"const Mat"` could match inside a longer type like `"const MatExpr &"`.

In practice, operator overloads typically return the same type, so false matches are unlikely but possible with types that are prefixes of other types (e.g., `Mat` vs `MatExpr`).

**Fix:** Use word boundary matching or exact type comparison after stripping qualifiers.

### #5 — Core: `NameMapper.from_config` crashes on nil `from` key
**File:** `lib/ruby-bindgen/name_mapper.rb:21-23`

If a YAML config entry has `from: null` or a missing `from` key, `key` becomes `nil` and line 23 crashes with `NoMethodError: undefined method 'start_with?' for nil`.

```ruby
key = entry[:from] || entry["from"]
if key.start_with?('/') && key.end_with?('/')  # crashes if key is nil
```

**Fix:** Guard with `if key&.start_with?('/') && key&.end_with?('/')`, or skip entries with nil keys.

### #6 — Core: `Symbols.add_entry` same nil crash
**File:** `lib/ruby-bindgen/symbols.rb:220-221`

Same pattern as #5 — `name.start_with?('/')` crashes if `name` is nil. Less likely since `add_entry` is called from `initialize` with guarded arrays, but a config with `skip: [null]` would trigger it.

**Fix:** Guard with `return if name.nil?` at the top of `add_entry`.

### #7 — Test: `Outputter` vs `TestOutputter` API mismatch
**File:** `test/cmake_test.rb:25`, `lib/ruby-bindgen/outputter.rb:13`, `test/test_outputter.rb:13`

`Outputter.output_paths` is an **Array**, but `TestOutputter.output_paths` is a **Hash**. The cmake test calls `.keys` on it (line 25), which only works because tests use `TestOutputter`. If someone uses the production `Outputter` in tests, it would crash.

**Fix:** Standardize the interface — either both use Hash or both use Array. Since `TestOutputter` needs path→content mapping for golden file comparison, consider making `Outputter.output_paths` a Hash too, or add a `paths` method that returns just the keys.

## LOW Severity

### #8 — Outputter: unused `require 'find'`
**File:** `lib/ruby-bindgen/outputter.rb:4`

`require 'find'` is never used. Dead import.

**Fix:** Remove line.

### #9 — Compile test: error filtering is fragile
**File:** `test/compile_rice_test.rb:28`

```ruby
compile_errors = output.lines.select { |line| line.include?("error") && !line.include?("LNK") }
```

Matches any line containing the word "error" (including warnings mentioning `-Werror`, build tool output, etc.) and only excludes MSVC linker errors (`LNK`). Won't exclude MinGW linker errors (`undefined reference`).

**Fix:** Use more precise patterns like `line =~ / error:/ || line =~ /error C\d{4}/`.

### #10 — Test: stale file `test/operators.rb`
**File:** `test/operators.rb`

Not a Minitest class, not imported by any test. Appears to be leftover scratch code.

**Fix:** Delete if unused.

## Not Issues (False Positives from Review)

- **Rice line 509 `@classes` stores `cursor.qualified_name`**: `@classes` values are never read — only keys are checked with `.key?()`. The value is irrelevant.
- **`enum_constant_decl.erb` nil on `semantic_parent.semantic_parent`**: Already guarded by commit 1626918. Anonymous enums always have a grandparent.
- **`arg0_type.delete("&")` mutates string**: `String#delete` returns a new string, does not mutate. Agent was wrong.
- **CMake path escaping**: Generated paths come from filesystem globs, not user input. Quotes in paths are not a realistic scenario.
- **Parser TU disposal**: AutoPointer handles via GC (confirmed in Round 1).
