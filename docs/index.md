# ruby-bindgen

RubyBindgen generates Ruby bindings from C and C++ header files. It uses [libclang](https://clang.llvm.org/doxygen/group__CINDEX.html), via the [ffi-clang](https://github.com/ioquatix/ffi-clang) gem, to parse header files and traverse the Clang AST using the visitor pattern.

Two visitors are implemented:
- **FFI** - For C libraries, generates [FFI](https://github.com/ffi/ffi) bindings
- **Rice** - For C++ libraries, generates [Rice](https://github.com/ruby-rice/rice) bindings

If a library provides both a C and C++ API, use the C API! It will likely be much easier to develop a Ruby extension using the C API and will also likely be more stable between releases.

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
