## 1.0.0 (2026-04-26)

First public release.

ruby-bindgen generates Rice C++ bindings, raw FFI bindings, and CMake build files
for Ruby extensions wrapping C and C++ libraries. It is driven by libclang and
configured via YAML.

### Tested against

- Ruby 3.2, 3.3, 3.4, and 4.0 on Linux and macOS.
- Ruby 4.0 on Windows (MSVC and MinGW).
- LLVM/libclang 17 and newer.

### Highlights since pre-release

- Skip `= delete` free functions automatically. The Rice generator now uses
  `clang_getCursorAvailability` rather than `clang_CXXMethod_isDeleted` so the
  rvalue-deletion idiom (e.g. OpenCV's `cv::to_own(Mat&&) = delete`) is handled
  without manual workarounds.
- Skip deprecated fields. `visit_field_decl` now respects
  `cursor.availability == :deprecated`, picking up both standard
  `[[deprecated]]` and the GCC/MSVC vendor attributes
  (`__attribute__((deprecated))` / `__declspec(deprecated)`) that OpenCV's
  `CV_DEPRECATED_EXTERNAL` macro produces.
- Default arguments built from `T{}` now strip cv-ref qualifiers via libclang's
  `non_reference_type` and `unqualified_type`, fixing malformed
  `static_cast<T &&>(T &{})` output for rvalue-reference parameters.
- Iterator-trait inference uses `non_reference_type` and `unqualified_type` for
  the value type, so primitive value types no longer leak `const` into
  `using reference = const const int&;` (invalid C++).
