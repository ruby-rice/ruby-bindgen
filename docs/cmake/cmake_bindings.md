# CMake Bindings

The `CMake` format generates `CMakeLists.txt` and `CMakePresets.json` files for building Rice C++ bindings.

Rice supports building extensions with either [extconf.rb](https://ruby-rice.github.io/4.x/packaging/extconf.rb/) or [CMake](https://ruby-rice.github.io/4.x/packaging/cmake/). While `extconf.rb` works for simple bindings, CMake is vastly superior for anything more complex — it provides better cross-platform support, dependency management, and build configuration.

**Important:** CMake generation must run after Rice generation because it scans the output directory for `*-rb.cpp` files. If no Rice output exists, the generated CMake source lists will be empty.

## Getting Started

See [Getting Started](getting_started.md) for a step-by-step guide.

## Output

See [Output](output.md) for details on the generated files.

## Filtering

See [Filtering](filtering.md) for how to exclude files from the generated CMake build and how to conditionally include generated sources and directories with `guards`.
