# Getting Started with FFI Bindings

This guide walks you through generating Ruby FFI bindings for a C library.

## 1. Create a configuration file

Create a file named `ffi-bindings.yaml`:

```yaml
project: mylib
input: ./include
output: ./lib/generated
format: FFI

match:
  - "**/*.h"

library_names:
  - mylib

clang:
  args:
    - -I./include
    - -xc
```

Key options:

- `project` — name used for the project file (`mylib_ffi.rb`) and the Ruby module
- `input` — directory containing header files
- `output` — where generated Ruby files are written
- `library_names` — shared library names to load at runtime (e.g., `mylib` for `libmylib.so`)
- `match` — glob patterns selecting which headers to process
- `clang.args` — compiler arguments; `-xc` tells clang to parse as C

Paths are relative to the config file's directory, not the working directory.

See [Configuration](../configuration.md) for all options, including [library versioning](../configuration.md#c-ffi-options), [symbol filtering](../configuration.md#symbols), and [version guards](../configuration.md#versions).

## 2. Generate bindings

```bash
ruby-bindgen ffi-bindings.yaml
```

This produces a project file, one Ruby file per matched header, and optionally a version stub file. See [FFI Output](output.md) for details.

## 3. Use the bindings

```ruby
require_relative 'lib/generated/mylib_ffi'

result = Mylib.my_function(42, "hello")
```

The project file (`mylib_ffi.rb`) loads the native library and requires all content files. You only need to require the project file.
