# Configuration

Ruby-bindgen uses a YAML configuration file to specify how bindings should be generated. This approach keeps your build configuration versioned and reproducible.

## Usage

```bash
ruby-bindgen config.yaml
```

## Configuration File Format

```yaml
# Name of the generated Ruby extension (optional)
# Must be a valid C/C++ identifier (letters, numbers, underscores)
# If omitted, only per-file bindings are generated without project wrapper files
extension: my_extension

# Custom Rice include header (optional)
# If not specified, a default header with rice.hpp and stl.hpp is generated
# Use this to add custom Type<T> specializations for smart pointers, etc.
include: my_rice_include.hpp

# Path to the directory containing header files (can be relative to this config file)
input: /path/to/headers

# Path to the output directory for generated bindings (can be relative to this config file)
output: /path/to/output

# Binding format: "Rice" (C++), "FFI" (C), or "CMake" (CMakeLists.txt)
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

# === Compiler Toolchain (platform-specific) ===
# Use clang-cl: for MSVC (Ruby platform contains 'mswin')
# Use clang: for everything else (Linux, macOS, MinGW)

clang-cl:
  # Path to libclang shared library (optional, auto-detected if omitted)
  libclang: C:/Program Files/Microsoft Visual Studio/2022/Professional/VC/Tools/Llvm/x64/bin/libclang.dll
  # Clang compiler arguments: include paths, language standard, defines, etc.
  args:
    - -IC:/Program Files/Microsoft Visual Studio/2022/Professional/VC/Tools/MSVC/14.38.33130/include
    - -IC:/Program Files (x86)/Windows Kits/10/Include/10.0.22621.0/ucrt
    - -xc++

clang:
  libclang: /usr/lib64/libclang.so
  args:
    - -I/usr/lib/clang/17/include
    - -I/usr/include/c++/13
    - -xc++
```

## Configuration Options

### Required Options

| Option | Description |
|--------|-------------|
| `input` | Directory containing the header files to parse. Can be absolute or relative to the config file location. |
| `output` | Directory where generated binding files will be written. Can be absolute or relative to the config file location. |
| `format` | Type of bindings to generate: `Rice` for C++, `FFI` for C, or `CMake` for CMakeLists.txt generation. |

**Note:** Relative paths for `input` and `output` are resolved from the config file's directory, not the current working directory. This makes configs portable across different machines.

### Optional Options

| Option | Default | Description |
|--------|---------|-------------|
| `extension` | none | Name of the Ruby extension. Used for the `Init_` function name. Must be a valid C/C++ identifier. When provided, generates project wrapper files (`{extension}-rb.cpp`, `{extension}-rb.hpp`, `{extension}.def`). When omitted, only per-file bindings are generated. |
| `include` | auto-generated | Path to a custom Rice include header. See [Include Header](#include-header) for details. |
| `match` | `["**/*.{h,hpp}"]` | Glob patterns specifying which header files to process. |
| `skip` | `[]` | Glob patterns specifying which header files to skip. |
| `export_macros` | `[]` | List of macros that indicate a symbol is exported. Only functions/classes with these macros will be included. |
| `skip_symbols` | `[]` | List of symbol names to skip. Supports simple names (`versionMajor`), fully qualified names (`cv::ocl::PlatformInfo::versionMajor`), or regex patterns (`/pattern/`). |
| `include_dirs` | `[]` | List of include directories for the CMake `target_include_directories` directive. These are CMake expressions written directly into `CMakeLists.txt` (e.g., `${CMAKE_CURRENT_SOURCE_DIR}/../headers`). Only used with `format: CMake`. |

### Compiler Toolchain Options

The compiler toolchain is configured using `clang-cl:` (for MSVC) or `clang:` (for Linux/macOS/MinGW) top-level keys:

| Option | Default | Description |
|--------|---------|-------------|
| `clang-cl:` | - | Compiler settings for MSVC platform (when `RUBY_PLATFORM` contains `mswin`). |
| `clang:` | - | Compiler settings for all other platforms (Linux, macOS, MinGW). |
| `libclang` | auto-detect | Path to the libclang shared library. Nested under `clang-cl:` or `clang:`. When specified, sets the `LIBCLANG` environment variable before loading ffi-clang. |
| `args` | `[]` | Arguments passed to libclang for parsing (include paths, language standard, defines, etc.). Nested under `clang-cl:` or `clang:`. |

## Example: OpenCV Bindings

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

# Only wrap functions marked with OpenCV export macros
export_macros:
  - CV_EXPORTS
  - CV_EXPORTS_W

# === Compiler Toolchain (platform-specific) ===
clang-cl:
  libclang: C:/Program Files/Microsoft Visual Studio/2022/Professional/VC/Tools/Llvm/x64/bin/libclang.dll
  args:
    - -IC:/Program Files/Microsoft Visual Studio/2022/Professional/VC/Tools/MSVC/14.38.33130/include
    - -IC:/Program Files (x86)/Windows Kits/10/Include/10.0.22621.0/ucrt
    - -IC:/Program Files/Microsoft Visual Studio/2022/Professional/VC/Tools/Llvm/lib/clang/16/include
    - -I/path/to/opencv/include/opencv4
    - -xc++

clang:
  libclang: /usr/lib64/libclang.so
  args:
    - -I/usr/lib/clang/17/include
    - -I/usr/include/c++/13
    - -I/path/to/opencv/include/opencv4
    - -xc++
```

## Platform-Specific Configuration

Ruby-bindgen uses top-level toolchain keys to configure compiler settings for different platforms:

- **`clang-cl:`**: Used when Ruby is built with MSVC (`RUBY_PLATFORM` contains `mswin`)
- **`clang:`**: Used for all other platforms (Linux, macOS, MinGW)

Each toolchain section contains:
- `libclang`: Path to the libclang shared library (optional, auto-detected if omitted)
- `args`: Array of arguments passed to libclang for parsing

This structure allows a single configuration file to work across different development environments:

```yaml
clang-cl:
  libclang: C:/Program Files/Microsoft Visual Studio/.../libclang.dll
  args:
    - -IC:/Program Files/Microsoft Visual Studio/.../include
    - -xc++

clang:
  libclang: /usr/lib64/libclang.so
  args:
    - -I/usr/lib/clang/17/include
    - -I/usr/include/c++/13
    - -xc++
```

You only need to include the toolchain sections for platforms you target.

## Clang Arguments

The `args` section under each toolchain is crucial for successful parsing. You typically need:

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

## Libclang Path

The `libclang` option specifies the path to the libclang shared library. This is useful when:

- You have multiple LLVM/Clang versions installed
- Clang is installed in a non-standard location
- ffi-clang fails to auto-detect the library

### Finding Libclang

On Linux:
```bash
# Common locations
/usr/lib64/libclang.so           # Fedora, RHEL
/usr/lib/x86_64-linux-gnu/libclang-*.so  # Debian, Ubuntu
/usr/lib/llvm-*/lib/libclang.so  # Multiple LLVM versions

# Find all libclang installations
find /usr -name "libclang*.so" 2>/dev/null
```

On macOS:
```bash
# Homebrew LLVM
/opt/homebrew/opt/llvm/lib/libclang.dylib  # Apple Silicon
/usr/local/opt/llvm/lib/libclang.dylib     # Intel

# Xcode Command Line Tools
/Library/Developer/CommandLineTools/usr/lib/libclang.dylib
```

On Windows:
```
# Visual Studio bundled LLVM
C:\Program Files\Microsoft Visual Studio\2022\...\VC\Tools\Llvm\x64\bin\libclang.dll

# Standalone LLVM installation
C:\Program Files\LLVM\bin\libclang.dll
```

### Example Configuration

```yaml
# Cross-platform configuration (recommended)
clang-cl:
  libclang: C:/Program Files/Microsoft Visual Studio/2022/Professional/VC/Tools/Llvm/x64/bin/libclang.dll
  args:
    - -IC:/Program Files/Microsoft Visual Studio/...
    - -xc++

clang:
  libclang: /usr/lib64/libclang.so  # or /opt/homebrew/opt/llvm/lib/libclang.dylib on macOS
  args:
    - -I/usr/lib/clang/17/include
    - -xc++
```

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
- **Regex patterns**: `/pattern/` - skips symbols matching the regex

```yaml
skip_symbols:
  - versionMajor                           # Skips all symbols named "versionMajor"
  - cv::ocl::PlatformInfo::versionMinor    # Skips only this specific method
  - /cv::dnn::.*Layer::init.*/             # Regex: skips all init* methods on any Layer class
```

### Regex Patterns

Regex patterns are enclosed in forward slashes (`/pattern/`) and are matched against both the simple symbol name and the fully qualified name. This is particularly useful for:

- Matching across versioned inline namespaces (e.g., `cv::dnn::dnn4_v20241223::Layer`)
- Skipping families of related methods
- Handling template specializations

```yaml
skip_symbols:
  # Skip all backend initialization methods on Layer classes
  # Matches cv::dnn::Layer::initCUDA, cv::dnn::dnn4_v20241223::Layer::initHalide, etc.
  - /cv::dnn::.*Layer::(init|applyHalideScheduler|tryAttach)/

  # Skip all operator() methods on DefaultDeleter templates
  - /cv::DefaultDeleter<.*>::operator\(\)/
```

Ruby-bindgen automatically skips:
- Deprecated functions (marked with `__attribute__((deprecated))`)
- Internal functions (names ending with `_`)
- Methods returning pointers to incomplete types (pimpl pattern)

## Include Header

The `include` option specifies a custom header file that all generated translation unit headers will include. This header centralizes Rice includes and any custom type support your bindings require.

### Default Behavior

When `include` is not specified, ruby-bindgen generates a default header named `{extension}_include.hpp` (or `rice_include.hpp` if no extension is specified):

```cpp
// Default Rice include header generated by ruby-bindgen
// To customize, create your own header and specify it with the 'include:' config option
#include <rice/rice.hpp>
#include <rice/stl.hpp>
```

All generated headers include this file:

```cpp
#include "../../my_extension_include.hpp"  // relative path computed automatically

void Init_MyClass();
```

### Custom Include Header

Specify a custom header when you need:

- Custom `Rice::detail::Type<T>` specializations for smart pointers or other types
- Additional Rice headers like `<rice/rice_api.hpp>`
- Project-specific includes or macros

```yaml
include: "my_rice_include.hpp"
```

Your custom header must include the Rice headers:

```cpp
// my_rice_include.hpp
#include <rice/rice.hpp>
#include <rice/stl.hpp>

// Custom Type specialization for library's smart pointer
namespace Rice::detail
{
  template<typename T>
  struct Type<MyLib::Ptr<T>>
  {
    static bool verify()
    {
      // Register the smart pointer type with Rice
      define_mylib_ptr<T>();
      return Type<T>::verify();
    }
  };
}
```

### Why This Matters

C++ templates are instantiated per translation unit. If different translation units see different template definitions (e.g., one sees a `Type<T>` specialization and another doesn't), this causes an ODR (One Definition Rule) violation. The linker may silently pick the wrong instantiation, leading to subtle bugs.

By centralizing all Rice includes in a single header that every generated file includes, all translation units see the same template definitions, preventing ODR violations.

### Precompiled Headers

The include header is an ideal candidate for precompiled headers (PCH). Since every generated file includes it, precompiling this header can significantly speed up build times:

```cmake
# CMake example
target_precompile_headers(my_extension PRIVATE
  "${CMAKE_SOURCE_DIR}/my_rice_include.hpp"
)
```
