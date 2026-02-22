# Examples

Minimal end-to-end examples for each output format.

## Rice (C++)

Reference project (fully automated Rice bindings): [BitmapPlusPlus-ruby](https://ruby-rice.github.io/BitmapPlusPlus-ruby/)

`bindings.yaml`:

```yaml
extension: sample_ext
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
mkdir -p ./ext/generated
ruby-bindgen bindings.yaml
```

Output:
- One `*-rb.cpp` and `*-rb.hpp` per header
- Optional `*-rb.ipp` files when template `_instantiate` functions are generated
- Project files when `extension` is set (`sample_ext-rb.cpp`, `sample_ext-rb.hpp`)

## FFI (C)

`bindings.yaml`:

```yaml
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
mkdir -p ./lib/generated
ruby-bindgen bindings.yaml
```

Output:
- One Ruby file per header with `FFI::Library`, enum/struct/callback definitions, and `attach_function` calls

## CMake (for Rice output)

Generate Rice code first, then CMake files.

`rice.yaml`:

```yaml
extension: sample_ext
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

`cmake.yaml`:

```yaml
extension: sample_ext
input: ./include
output: ./ext/generated
format: CMake

include_dirs:
  - "${CMAKE_CURRENT_SOURCE_DIR}/../include"
```

Run:

```bash
mkdir -p ./ext/generated
ruby-bindgen rice.yaml
ruby-bindgen cmake.yaml
```

Then build:

```bash
cd ./ext/generated
cmake --preset linux-debug
cmake --build build/linux-debug
```
