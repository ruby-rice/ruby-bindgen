# Prior Art

This page lists related projects and adjacent tools that influenced, overlap with, or can complement `ruby-bindgen`.

## Related Ruby Binding Generators

### ffi_gen

- Project: https://github.com/ffi/ffi_gen
- Scope: Generate Ruby FFI wrappers for C APIs
- Notes: Historical reference point for C-oriented generation in the Ruby ecosystem.

### rbind

- Project: https://github.com/D-Alex/rbind
- Scope: C++ binding generator with a custom parser approach
- Notes: Relevant comparison for C++ wrapping goals and parser tradeoffs.

## Adjacent Ecosystem Tools

### Rice

- Project: https://github.com/ruby-rice/rice
- Scope: C++ library for implementing Ruby native extensions
- Relationship to `ruby-bindgen`: `ruby-bindgen` can generate Rice-oriented C++ wrapper code.

### ffi-clang

- Project: https://github.com/ioquatix/ffi-clang
- Scope: Ruby FFI bindings to libclang
- Relationship to `ruby-bindgen`: provides AST access used for parsing headers.

### Magnus

- Project: https://github.com/matsadler/magnus
- Scope: Rust crate for Ruby bindings
- Notes: Not a direct Ruby generator alternative for C/C++, but useful as a design reference for Ruby-native APIs from another language.

## Positioning Summary

- `ruby-bindgen` focuses on generation from C/C++ headers with multiple output formats (`Rice`, `FFI`, `CMake`).
- Compared with older generator projects, it emphasizes modern C++ edge cases and large-library workflows.
- In practice, tools in this list can be alternatives for some use cases, or dependencies/complements in a broader pipeline.
