# CMake Bindings

The `CMake` format generates `CMakeLists.txt` and `CMakePresets.json` files for building Rice C++ bindings. This is typically run as a second pass after generating the Rice binding source files.

## Usage

The CMake format scans the output directory for `*-rb.cpp` files produced by the Rice format and generates:

- **`CMakeLists.txt`** (top-level) - Project configuration with Rice fetching, Ruby detection, and source file listing
- **`CMakeLists.txt`** (per subdirectory) - Source file listing for each subdirectory
- **`CMakePresets.json`** - Build presets for Linux, macOS, MSVC, MinGW, and Clang on Windows (debug and release variants)

## Configuration

```yaml
format: CMake
extension: my_extension

# CMake expressions for target_include_directories
include_dirs:
  - "${CMAKE_CURRENT_SOURCE_DIR}/../headers"
```

### Options

| Option | Description |
|--------|-------------|
| `extension` | Project name used in `project()` and target name. Required. |
| `include_dirs` | List of include directory expressions added via `target_include_directories`. These are written directly into CMakeLists.txt, so CMake variables like `${CMAKE_CURRENT_SOURCE_DIR}` work. |

## Generated CMakeLists.txt

The top-level `CMakeLists.txt` includes:

- C++17 standard requirement
- Rice fetched from GitHub via `FetchContent`
- Ruby detection via `find_package(Ruby)`
- Library target (SHARED on MSVC, MODULE elsewhere)
- Extension output configuration (correct suffix, visibility settings)
- All `*-rb.cpp` source files

## Workflow

Generate bindings in two passes:

```bash
# Ensure output directory exists
mkdir -p /path/to/output

# 1. Generate Rice C++ source files
ruby-bindgen rice_config.yaml

# 2. Generate CMake build files
ruby-bindgen cmake_config.yaml
```

Then build:

```bash
cd /path/to/output
cmake --preset linux-debug    # or msvc-debug, macos-debug, etc.
cmake --build build/linux-debug
```

## Build Presets

The generated `CMakePresets.json` includes presets for all major platforms:

| Preset | Platform | Compiler |
|--------|----------|----------|
| `linux-debug` / `linux-release` | Linux | GCC/Clang |
| `macos-debug` / `macos-release` | macOS | Clang |
| `msvc-debug` / `msvc-release` | Windows | MSVC |
| `mingw-debug` / `mingw-release` | Windows | MinGW GCC |
| `clang-windows-debug` / `clang-windows-release` | Windows | clang-cl |

All presets use Ninja as the build generator and include appropriate compiler flags for each platform (visibility settings, debug info, optimization levels).
