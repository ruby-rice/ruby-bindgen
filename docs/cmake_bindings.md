# CMake Bindings

The `CMake` format generates `CMakeLists.txt` and `CMakePresets.json` files for building Rice C++ bindings. This is run as a second pass after generating the Rice binding source files.

Rice supports building extensions with either [extconf.rb](https://ruby-rice.github.io/4.x/packaging/extconf.rb/) or [CMake](https://ruby-rice.github.io/4.x/packaging/cmake/). While `extconf.rb` works for simple bindings, CMake is vastly superior for anything more complex — it provides better cross-platform support, dependency management, and build configuration.

## Configuration

```yaml
format: CMake
project: my_extension

include_dirs:
  - "${CMAKE_CURRENT_SOURCE_DIR}/../headers"
```

See [configuration](configuration.md) for details on all options.

## Usage

Generate bindings in two passes:

```bash
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

## Output

The CMake format scans the output directory for `*-rb.cpp` files and generates:

``` mermaid
flowchart LR
    subgraph Input
        CF["cmake_config.yaml"]
        S1["*-rb.cpp"]
    end

    CF & S1 --> RB["ruby-bindgen"]

    subgraph "CMake Output"
        C1["CMakeLists.txt"]
        C2["CMakePresets.json"]
    end

    RB --> C1 & C2
```

### Project Files (requires `project`)

When the `project` option is set, `ruby-bindgen` generates the root `CMakeLists.txt` and `CMakePresets.json`. When `project` is omitted, these files are **not** generated — only subdirectory `CMakeLists.txt` files are produced. This is useful when you want to create and manage the root project files yourself and only regenerate subdirectory files on subsequent runs.

### Top Level

The top-level `CMakeLists.txt` is a complete project file that configures the entire build:

- C++17 standard requirement
- Rice fetched from GitHub via `FetchContent`
- Ruby detection via `find_package(Ruby)`
- Library target (SHARED on MSVC, MODULE elsewhere)
- Extension output configuration (correct suffix, visibility settings)
- Subdirectory includes and `*-rb.cpp` source file listing

For a well-documented example, see the [BitmapPlusPlus-ruby CMakeLists.txt](https://github.com/ruby-rice/BitmapPlusPlus-ruby/blob/main/ext/CMakeLists.txt). For details on how Rice uses CMake, see the Rice [CMake](https://ruby-rice.github.io/4.x/packaging/cmake/) documentation.

The top-level directory also gets a `CMakePresets.json` with build presets for all major platforms. For an example, see the [BitmapPlusPlus-ruby CMakePresets.json](https://github.com/ruby-rice/BitmapPlusPlus-ruby/blob/main/ext/CMakePresets.json). For details, see the Rice [CMakePresets.json](https://ruby-rice.github.io/4.x/packaging/cmake/#cmakepresetsjson) documentation.

| Preset | Platform | Compiler |
|--------|----------|----------|
| `linux-debug` / `linux-release` | Linux | GCC/Clang |
| `macos-debug` / `macos-release` | macOS | Clang |
| `msvc-debug` / `msvc-release` | Windows | MSVC |
| `mingw-debug` / `mingw-release` | Windows | MinGW GCC |
| `clang-windows-debug` / `clang-windows-release` | Windows | clang-cl |

All presets use [Ninja](https://ninja-build.org/) as the build generator and include appropriate compiler flags for each platform (visibility settings, debug info, optimization levels).

### Subdirectories

Each subdirectory containing `*-rb.cpp` files gets a minimal `CMakeLists.txt` that lists its source files and any nested subdirectories:

```cmake
# Subdirectories
add_subdirectory("hal")

# Sources
target_sources(${CMAKE_PROJECT_NAME} PUBLIC
  "matrix-rb.cpp"
  "image-rb.cpp"
)
```
