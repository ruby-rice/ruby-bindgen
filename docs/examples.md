# Examples

## Reference projects

Three published gems use `ruby-bindgen` and are good places to read working
configuration, layout, and CI when starting your own bindings project.

| Project                                                                 | Format     | Size       | When to use as a reference                                                                                                          |
|-------------------------------------------------------------------------|------------|------------|-------------------------------------------------------------------------------------------------------------------------------------|
| [BitmapPlusPlus-ruby](https://ruby-rice.github.io/BitmapPlusPlus-ruby/) | Rice (C++) | ~1 file    | Wrapping a small, header-only C++ library. The cleanest end-to-end gem layout (ext/, lib/, sig/, test/, docs/, CMakePresets.json). |
| [proj4rb](https://cfis.github.io/proj4rb/)                              | FFI (C)    | medium     | Wrapping a C library via FFI rather than a compiled extension. Shows library loading, version pinning, and Ruby-side wrappers.     |
| [opencv-ruby](https://github.com/cfis/opencv-ruby)                      | Rice (C++) | very large | Wrapping a large, complex C++ library that needs heavy customization, CUDA guards, and post-regeneration manual edits.            |

For learning, start with **BitmapPlusPlus-ruby** for C++ or **proj4rb** for C.
Read **opencv-ruby** later, as a study of how to scale the same approach to
1,000+ classes and 10,000+ method bindings.

## Minimal config snippets

Minimal end-to-end examples for each output format.

## Rice (C++)

`rice-bindings.yaml`:

```yaml
project: sample_ext
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

Run:

```bash
ruby-bindgen rice-bindings.yaml
```

Output:
- One `*-rb.cpp` and `*-rb.hpp` per header
- Optional `*-rb.ipp` files when template `_instantiate` functions are generated
- Project files when `project` is set (`sample_ext-rb.cpp`, `sample_ext-rb.hpp`)

## FFI (C)

`ffi-bindings.yaml`:

```yaml
project: mylib
input: ./include
output: ./lib/generated
format: FFI

match:
  - "**/*.h"

library_names:
  - mylib
library_versions:
  - "2"
  - "1"

clang:
  args:
    - -I./include
    - -xc
```

Run:

```bash
ruby-bindgen ffi-bindings.yaml
```

Output:
- A project loader file (`mylib_ffi.rb`) with `require 'ffi'`, `ffi_lib`, and `require_relative` calls
- One Ruby content file per header with enums, structs, callbacks, and `attach_function` calls

## CMake (for Rice output)

**Important:** CMake generation must run after Rice generation because it scans the output directory for `*-rb.cpp` files.

`rice-bindings.yaml`:

```yaml
project: sample_ext
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

`cmake-bindings.yaml`:

```yaml
project: sample_ext
output: ./ext/generated
format: CMake
# input defaults to output for CMake and scans ./ext/generated for *-rb.cpp

include_dirs:
  - "${CMAKE_CURRENT_SOURCE_DIR}/../include"
```

Run:

```bash
ruby-bindgen rice-bindings.yaml
ruby-bindgen cmake-bindings.yaml
```

Then build:

```bash
cd ./ext/generated
cmake --preset linux-debug
cmake --build build/linux-debug
```
