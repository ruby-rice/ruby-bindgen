# Configuration

`ruby-bindgen` uses a YAML configuration file to specify how bindings should be generated. This approach keeps your build configuration versioned and reproducible.

```bash
ruby-bindgen config.yaml
```

For end-to-end examples, see [C Bindings](c_bindings.md), [C++ Bindings](cpp/cpp_bindings.md), and [CMake Bindings](cmake_bindings.md).

## Required Options

| Option   | Description                                                                                                                |
|----------|----------------------------------------------------------------------------------------------------------------------------|
| `input`  | Directory containing the header files to parse. Can be absolute or relative to the config file location.                   |
| `output` | Existing directory where generated binding files will be written. Can be absolute or relative to the config file location. |
| `format` | Type of bindings to generate: `Rice` for C++, `FFI` for C, or `CMake` for CMakeLists.txt generation.                       |

**Note:** Relative paths for `input` and `output` are resolved from the config file's directory, not the current working directory. This makes configs portable across different machines.

## Common Options

These options apply to all formats.

| Option          | Default            | Description |
|-----------------|--------------------|-------------|
| `match`         | `["**/*.{h,hpp}"]` | Glob patterns specifying which header files to process. |
| `skip`          | `[]`               | Glob patterns specifying which header files to skip. |
| `skip_symbols`  | `[]`               | List of symbol names to skip. Supports simple names, fully qualified names, or regex patterns. See [Skip Symbols](#skip-symbols). |

## C (FFI) Options

| Option             | Default | Description |
|--------------------|---------|-------------|
| `library_names`    | `[]`    | Base names of shared libraries to load (e.g., `["proj"]` for `libproj`). |
| `library_versions` | `[]`    | Library version suffixes to search for (e.g., `["25", "9"]`). Combined with `library_names` to build platform-specific search names like `libproj.so.25`. |

## C++ (Rice) Options

| Option          | Default        | Description |
|-----------------|----------------|-------------|
| `extension`     | none           | Name of the Ruby extension. Used for the `Init_` function name. Must be a valid C/C++ identifier. When provided, generates project wrapper files (`{extension}-rb.cpp`, `{extension}-rb.hpp`). When omitted, only per-file bindings are generated. |
| `include`       | auto-generated | Path to a custom Rice include header. See [Include Header](cpp/cpp_bindings.md#include-header). |
| `export_macros` | `[]`           | List of macros that indicate a symbol is exported. See [Export Macros](cpp/filtering.md#export-macros). |

## CMake Options

| Option         | Default | Description |
|----------------|---------|-------------|
| `extension`    | none    | Project name used in `project()` and target name. Required. |
| `include_dirs` | `[]`    | List of include directory expressions added via `target_include_directories`. These are CMake expressions written directly into `CMakeLists.txt` (e.g., `${CMAKE_CURRENT_SOURCE_DIR}/../headers`). |

## Compiler Toolchain

`ruby-bindgen` uses top-level toolchain keys to configure compiler settings for different platforms:

- **`clang-cl:`** - Used when Ruby is built with MSVC (`RUBY_PLATFORM` contains `mswin`)
- **`clang:`** - Used for all other platforms (Linux, macOS, MinGW)

| Option     | Default     | Description |
|------------|-------------|-------------|
| `libclang` | auto-detect | Path to the libclang shared library. Nested under `clang-cl:` or `clang:`. When specified, sets the `LIBCLANG` environment variable before loading ffi-clang. |
| `args`     | `[]`        | Arguments passed to libclang for parsing (include paths, language standard, defines, etc.). Nested under `clang-cl:` or `clang:`. |

You only need to include the toolchain sections for platforms you target.

### Resolution Flow

```mermaid
flowchart TD
  A["config.yaml location"] --> B["Resolve relative input/output paths"]
  B --> C{"RUBY_PLATFORM contains mswin?"}
  C -->|Yes| D["Use clang-cl section"]
  C -->|No| E["Use clang section"]
  D --> F["Set LIBCLANG from toolchain libclang (if provided)"]
  E --> F
  F --> G["Pass toolchain args to libclang parser"]
```

### Clang Arguments

The `args` section under each toolchain is crucial for successful parsing. You typically need:

1. **System include paths** - Standard library headers
2. **Library include paths** - The library's own headers
3. **Language specification** - `-xc++` for C++ headers, `-xc` for C headers
4. **Language standard** - `-std=c++17` or similar

#### Finding System Include Paths

On Linux/macOS:
```bash
clang++ -E -x c++ - -v < /dev/null 2>&1 | grep "^ /"
```

On Windows with MSVC:
- Visual Studio include paths (e.g., `C:\Program Files\Microsoft Visual Studio\...\include`)
- Windows SDK include paths (e.g., `C:\Program Files (x86)\Windows Kits\10\Include\...`)
- LLVM/Clang include paths if using clang

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

`ruby-bindgen` automatically skips:
- Deprecated functions (marked with `__attribute__((deprecated))`)
- Internal functions (names ending with `_`)
- Methods returning pointers to incomplete types (pimpl pattern)
