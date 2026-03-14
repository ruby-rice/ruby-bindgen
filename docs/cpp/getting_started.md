# Getting Started with Rice Bindings

This guide walks you through generating Rice (C++) bindings for a C++ library.

## 1. Create a configuration file

Create a file named `rice-bindings.yaml`:

```yaml
project: my_extension
input: ./include
output: ./ext/generated
format: Rice

match:
  - "**/*.hpp"

clang:
  args:
    - -I./include
    - -std=c++17
    - -xc++
```

Key options:

- `project` — name used for the extension init function (`Init_MyExtension`) and project wrapper files
- `input` — directory containing header files
- `output` — where generated C++ files are written
- `match` — glob patterns selecting which headers to process
- `clang.args` — compiler arguments; `-xc++` tells clang to parse as C++, `-std=c++17` sets the language standard

Paths are relative to the config file's directory, not the working directory.

See [Configuration](../configuration.md) for all options, including [symbol filtering](../configuration.md#symbols), [export macros](../configuration.md#export-macros), [name mappings](../configuration.md#name-mappings), and [version guards](../configuration.md#versions).

## 2. Generate bindings

```bash
ruby-bindgen rice-bindings.yaml
```

This produces `.cpp`, `.hpp`, and optionally `.ipp` files for each matched header, plus project wrapper files. See [Rice Output](output.md) for details.

## 3. Generate CMake build files (optional)

If you want `ruby-bindgen` to generate CMake build files, create a second config:

`cmake-bindings.yaml`:

```yaml
project: my_extension
output: ./ext/generated
format: CMake

include_dirs:
  - "${CMAKE_CURRENT_SOURCE_DIR}/../include"
```

Then run it **after** the Rice generation:

```bash
ruby-bindgen cmake-bindings.yaml
```

See [CMake Bindings](../cmake/cmake_bindings.md) for details.

## 4. Build the extension

```bash
cd ./ext/generated
cmake --preset linux-debug    # or macos-debug, msvc-debug, etc.
cmake --build build/linux-debug
```

## 5. Packaging

For packaging your extension as a gem, see the Rice [Packaging](https://ruby-rice.github.io/4.x/packaging/packaging/) documentation.

For a complete, fully automated example see [BitmapPlusPlus-ruby](https://ruby-rice.github.io/BitmapPlusPlus-ruby/).
