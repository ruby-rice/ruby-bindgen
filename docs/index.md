# ruby-bindgen

Automatically generate Ruby bindings from C and C++ header files.

Writing Ruby bindings for C++ libraries by hand is tedious and error-prone. A library like OpenCV has thousands of classes, methods, and functions. Creating bindings manually would take months of work and be difficult to maintain as the library evolves. ruby-bindgen automates this process, turning weeks of work into hours.

## Ecosystem

ruby-bindgen is part of a toolchain for wrapping C++ libraries for Ruby:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            C++ Library                                  │
│                         (headers + source)                              │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Clang / ffi-clang                               │
│                        (parse C++ headers)                              │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           ruby-bindgen                                  │
│                    (generate Rice binding code)                         │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                              Rice                                       │
│            (type conversion, memory management, introspection)          │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         CMake / Build System                            │
│                        (compile the extension)                          │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            Ruby Gem                                     │
│                    (compiled extension + RBS types)                     │
└─────────────────────────────────────────────────────────────────────────┘
```

### Toolchain Components

| Component | Purpose |
|-----------|---------|
| **[Clang](https://clang.llvm.org/)** | C/C++ compiler providing libclang for parsing |
| **[ffi-clang](https://github.com/ioquatix/ffi-clang)** | Ruby bindings to libclang for AST traversal |
| **ruby-bindgen** | Walks the AST and generates binding code |
| **[Rice](https://github.com/ruby-rice/rice)** | C++ library for type conversion, memory management, and Ruby integration |
| **[CMake](https://cmake.org/)** | Build system for compiling native extensions |

## Binding Formats

ruby-bindgen supports two output formats:

| Format | Library | Use Case |
|--------|---------|----------|
| **Rice** | [Rice](https://github.com/ruby-rice/rice) | C++ libraries |
| **FFI** | [FFI](https://github.com/ffi/ffi) | C libraries |

If a library provides both C and C++ APIs, prefer the C API. It's simpler to wrap and more stable across releases.

## What to Expect

ruby-bindgen aims to generate compilable code that handles 90-95% of the work. For many libraries, the generated bindings compile and work with minimal changes.

Occasional manual adjustments may be needed:
- Adding an `#include` for a type used in a method signature
- Renaming a Ruby method to better fit conventions
- Adding problematic symbols to `skip_symbols`
- Custom `Type<T>` specializations for complex template types

See [C++ Bindings](cpp_bindings.md#what-to-expect) for details.

After generating bindings, see Rice's packaging docs: [CMake](https://ruby-rice.github.io/4.x/packaging/cmake/) for building, [RBS](https://ruby-rice.github.io/4.x/packaging/rbs/) for type signatures, [Documentation](https://ruby-rice.github.io/4.x/packaging/documentation/) for API docs, and [Registries](https://ruby-rice.github.io/4.x/ruby_api/registries/) for introspection.

## Documentation

- [Configuration](configuration.md) - YAML configuration file format and options
- [Features](features.md) - Comprehensive list of supported C++ features
- [C Bindings](c_bindings.md) - FFI bindings for C libraries
- [C++ Bindings](cpp_bindings.md) - Rice bindings for C++ libraries
- [Iterators](iterators.md) - Iterator support details
- [Operators](operators.md) - Operator overloading support

## Quick Start

1. Create a YAML configuration file:

```yaml
extension: my_extension
input: /path/to/headers
output: /path/to/output
format: Rice

match:
  - "**/*.hpp"

clang_args:
  - -I/path/to/includes
  - -std=c++17
  - -xc++
```

2. Run ruby-bindgen:

```bash
ruby-bindgen config.yaml
```

See [Configuration](configuration.md) for full documentation of all options.

## Example: OpenCV Bindings

Ruby-bindgen was used to create C++ bindings for the [OpenCV](https://github.com/opencv/opencv) library. OpenCV is a large library with complex C++ patterns, making it a good test case.

```yaml
extension: opencv_ruby

input: /path/to/opencv/include/opencv4
output: /path/to/opencv-ruby/ext
format: Rice

# Custom header with cv::Ptr<T> type support
include: opencv_ruby_include.hpp

match:
  - opencv2/**/*.hpp

skip:
  - opencv2/core/opencl/**/*
  - opencv2/cudalegacy/**/*.hpp
  - opencv2/**/*.inl*

# Only wrap exported functions
export_macros:
  - CV_EXPORTS
  - CV_EXPORTS_W

# Skip problematic symbols
skip_symbols:
  - cv::ocl::PlatformInfo::versionMajor
  - cv::ocl::PlatformInfo::versionMinor
  - /cv::dnn::.*Layer::init.*/

clang_args:
  - -I/usr/include/c++/11
  - -I/path/to/opencv/include/opencv4
  - -std=c++17
  - -xc++
```

The output directory structure matches the input - ruby-bindgen automatically creates necessary subdirectories.

## Similar Work

* [ffi_gen](https://github.com/ffi/ffi_gen) - Unmaintained bindings generator for C
* [rbind](https://github.com/D-Alex/rbind) - Gem with custom C++ parser
* [Magnus](https://github.com/matsadler/magnus) - Bindings generator for Rust
