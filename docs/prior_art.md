# Prior Art

This page lists related projects and adjacent tools that influenced, overlap with, or can complement `ruby-bindgen`.

## C/C++

### SWIG

- Project: [SWIG](https://www.swig.org/)
- Scope: Multi-language binding generator for C and C++
- Notes: Generates bindings for many languages including Ruby, Python, Java, and Go. Uses its own interface definition files rather than parsing headers directly. The most established tool in this space — active since 1996.

### ffi_gen

- Project: [ffi_gen](https://github.com/ffi/ffi_gen)
- Scope: Generate Ruby FFI wrappers for C APIs
- Notes: Has not been updated in over a decade and includes liblang findings versus using [ffi-clang](https://github.com/ioquatix/ffi-clang).

### rbind

- Project: [rbind](https://github.com/D-Alex/rbind)
- Scope: C++ binding generator with a custom parser approach
- Notes: Has not been updated in four years and is coupled to OpenCV

## Rust

### Magnus

- Project: [magnus](https://github.com/matsadler/magnus)
- Scope: Rust crate for Ruby bindings
- Notes: Not a direct Ruby generator alternative for C/C++, but useful as a design reference for Ruby-native APIs from another language.

### rb-sys

- Project: [rb-sys](https://github.com/oxidize-rb/rb-sys)
- Scope: Rust bindings for the Ruby C API
- Notes: Provides low-level Rust bindings to Ruby, auto-generated from `ruby.h` using rust-bindgen.
