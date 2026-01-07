# Configuration

Ruby-bindgen uses a YAML configuration file to specify how bindings should be generated. This approach keeps your build configuration versioned and reproducible.

## Usage

```bash
ruby-bindgen config.yaml
```

## Configuration File Format

```yaml
# Name of the generated Ruby extension
# Must be a valid C/C++ identifier (letters, numbers, underscores)
extension: my_extension

# Path to the directory containing header files
input: /path/to/headers

# Path to the output directory for generated bindings
output: /path/to/output

# Binding format: "Rice" (C++) or "FFI" (C)
format: Rice

# Glob patterns for header files to process
match:
  - "**/*.hpp"
  - "**/*.h"

# Glob patterns for header files to skip
skip:
  - "**/internal/**"
  - "**/*.inl*"

# Symbol names to skip (functions, methods, classes)
# Supports simple names or fully qualified names (e.g., "cv::ocl::PlatformInfo::versionMajor")
skip_symbols:
  - internalFunction
  - MyNamespace::MyClass::privateMethod

# Clang compiler arguments
# Include paths, language standard, defines, etc.
clang_args:
  - -I/path/to/system/includes
  - -I/path/to/library/includes
  - -std=c++17
  - -xc++
```

## Configuration Options

### Required Options

| Option | Description |
|--------|-------------|
| `extension` | Name of the Ruby extension. Used for the `Init_` function name. Must be a valid C/C++ identifier. |
| `input` | Directory containing the header files to parse. |
| `output` | Directory where generated binding files will be written. |
| `format` | Type of bindings to generate: `Rice` for C++ or `FFI` for C. |

### Optional Options

| Option | Default | Description |
|--------|---------|-------------|
| `match` | `["**/*.{h,hpp}"]` | Glob patterns specifying which header files to process. |
| `skip` | `[]` | Glob patterns specifying which header files to skip. |
| `export_macros` | `[]` | List of macros that indicate a symbol is exported. Only functions/classes with these macros will be included. |
| `skip_symbols` | `[]` | List of symbol names to skip. Supports simple names (`versionMajor`) or fully qualified names (`cv::ocl::PlatformInfo::versionMajor`). |
| `clang_args` | `[]` | Arguments passed to libclang for parsing. Include paths, language options, etc. |

## Example: OpenCV Bindings

```yaml
extension: opencv_ruby

input: /path/to/opencv/include/opencv4
output: /path/to/opencv-ruby/ext
format: Rice

match:
  - opencv2/**/*.hpp

skip:
  - opencv2/core/opencl/**/*
  - opencv2/cudalegacy/**/*.hpp
  - opencv2/**/*.inl*

# Only wrap functions marked with OpenCV export macros
export_macros:
  - CV_EXPORTS
  - CV_EXPORTS_W

clang_args:
  - -I/usr/include/c++/11
  - -I/path/to/opencv/include/opencv4
  - -std=c++17
  - -xc++
```

## Clang Arguments

The `clang_args` section is crucial for successful parsing. You typically need:

1. **System include paths** - Standard library headers
2. **Library include paths** - The library's own headers
3. **Language specification** - `-xc++` for C++ headers
4. **Language standard** - `-std=c++17` or similar

### Finding System Include Paths

On Linux/macOS:
```bash
clang++ -E -x c++ - -v < /dev/null 2>&1 | grep "^ /"
```

On Windows with MSVC:
- Visual Studio include paths (e.g., `C:\Program Files\Microsoft Visual Studio\...\include`)
- Windows SDK include paths (e.g., `C:\Program Files (x86)\Windows Kits\10\Include\...`)
- LLVM/Clang include paths if using clang

## Export Macros

The `export_macros` option filters functions based on the presence of specific macros in the source code. This is particularly useful for libraries like OpenCV that use macros to control symbol visibility:

```yaml
export_macros:
  - CV_EXPORTS      # Basic export macro
  - CV_EXPORTS_W    # Export + wrapper generator hint
```

When `export_macros` is specified, only functions whose source text contains at least one of the listed macros will be included in the bindings. This prevents linker errors from trying to wrap internal functions that aren't exported from the shared library.

### Common Library Macros

| Library | Export Macros |
|---------|--------------|
| OpenCV | `CV_EXPORTS`, `CV_EXPORTS_W`, `CV_EXPORTS_W_SIMPLE` |
| Qt | `Q_DECL_EXPORT`, `Q_CORE_EXPORT` |
| Boost | `BOOST_*_DECL` |

## Skip Symbols

The `skip_symbols` option is useful when:

- Functions have export macros but still aren't available (build configuration issues)
- Functions are internal/private APIs not meant for external use
- Functions cause linker errors due to missing symbols

You can specify symbols using:
- **Simple names**: `versionMajor` - skips all symbols with this name
- **Fully qualified names**: `cv::ocl::PlatformInfo::versionMajor` - skips only that specific symbol

```yaml
skip_symbols:
  - versionMajor                           # Skips all symbols named "versionMajor"
  - cv::ocl::PlatformInfo::versionMinor    # Skips only this specific method
```

Ruby-bindgen automatically skips:
- Deprecated functions (marked with `__attribute__((deprecated))`)
- Internal functions (names ending with `_`)
- Methods returning pointers to incomplete types (pimpl pattern)
