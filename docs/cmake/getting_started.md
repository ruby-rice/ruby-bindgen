# Getting Started with CMake Bindings

This guide walks you through generating CMake build files for Rice C++ bindings.

## Prerequisites

You must first generate Rice C++ bindings. See [Getting Started with Rice](../cpp/getting_started.md).

## 1. Create a configuration file

Create a file named `cmake-bindings.yaml`:

```yaml
project: my_extension
output: ./ext/generated
format: CMake

guards:
  TARGET MyLib::gpu:
    - gpu
    - gpu/**/*-rb.cpp

include_dirs:
  - "${CMAKE_CURRENT_SOURCE_DIR}/../include"
```

Key options:

- `project` — name used in the CMake `project()` command and build target. When omitted, only subdirectory `CMakeLists.txt` files are generated — useful when you manage the root project files yourself.
- `output` — directory containing the Rice `*-rb.cpp` files. `input` defaults to `output` for CMake.
- `guards` — raw CMake conditions mapped to generated path patterns. Use this when a generated subdirectory or `*-rb.cpp` file should only be compiled when a module or feature is available.
- `include_dirs` — include directories added via `target_include_directories`. These are CMake expressions written directly into the generated `CMakeLists.txt`.

See [Configuration](../configuration.md) for all options.

## 2. Generate CMake files

Run this **after** generating Rice bindings:

```bash
ruby-bindgen cmake-bindings.yaml
```

## 3. Build

```bash
cd ./ext/generated
cmake --preset linux-debug    # or macos-debug, msvc-debug, mingw-debug, etc.
cmake --build build/linux-debug
```

See [Output](output.md) for details on the available presets and generated files.
