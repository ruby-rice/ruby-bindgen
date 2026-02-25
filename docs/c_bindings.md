# C Bindings

`ruby-bindgen` generates Ruby files that use the [FFI](https://github.com/ffi/ffi) gem to call C library functions. FFI allows Ruby to directly load and call functions from C shared libraries without writing a C extension. This means:

- **No compilation step** - Ruby loads the library at runtime
- **Easier distribution** - No need to compile native code for each platform
- **Simpler development** - No C code to write or debug

If a library provides a C API then use it!

## Configuration

First create a configuration file named `ffi-bindings.yaml`:

```yaml
input: ./include
output: ./lib/bindings
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

Then to generate bindings run:

```bash
mkdir -p ./lib/generated
ruby-bindgen ffi-bindings.yaml
```

## Output

For each C header file, `ruby-bindgen` generates a Ruby file with the same name. The generated file:

1. Creates a Ruby module extending `FFI::Library`
2. Loads the shared library with cross-platform name handling
3. Defines structs, unions, enums, and callbacks
4. Attaches functions and variables

Example output for a library called `mylib`:

```ruby
require 'ffi'

module Mylib
  extend FFI::Library

  def self.library_names
    ["mylib"]
  end

  def self.search_names
    # Cross-platform library name generation
    # Handles .so, .dylib, .dll variants
  end

  ffi_lib self.search_names

  # Structs
  class MyStruct < FFI::Struct
    layout :field1, :int,
           :field2, :double
  end

  # Enums
  MY_ENUM = enum(
    :value_one, 0,
    :value_two, 1
  )

  # Callbacks
  callback :my_callback, [:int, :pointer], :void

  # Functions
  attach_function :my_function, :my_function, [:int, :string], :int
end
```

## Supported Features

`ruby-bindgen` supports the following FFI features:

- [Functions](https://github.com/ffi/ffi/wiki/Basic-Usage) - C functions mapped to Ruby module methods via `attach_function`
- [Structs](https://github.com/ffi/ffi/wiki/Structs) - C structs mapped to `FFI::Struct` classes with proper layouts
- Unions - C unions mapped to `FFI::Union` classes
- [Enums](https://github.com/ffi/ffi/wiki/Enums) - C enums mapped to FFI enum types
- [Callbacks](https://github.com/ffi/ffi/wiki/Callbacks) - Function pointer types for C callbacks
- [Typedefs](https://github.com/ffi/ffi/wiki/Types) - Type aliases preserved in the generated code
- Forward declarations - Opaque struct types handled correctly
- Global variables - Exported variables via [`attach_variable`](https://www.rubydoc.info/gems/ffi/FFI/Library#attach_variable-instance_method)

## Examples

The test suite includes bindings generated from some popular C libraries:

| Library         | Description                       |
|-----------------|-----------------------------------|
| [PROJ](https://proj.org/)     | Coordinate transformation library |
| [SQLite](https://sqlite.org/)   | Database engine                   |
| [libclang](https://clang.llvm.org/) | C/C++ parsing library             |

See [test/headers/c](../test/headers/c) for the input headers and [test/bindings/c](../test/bindings/c) for the generated Ruby bindings.

## Library Loading

FFI needs to find and load the C shared library at runtime. The `library_names` and `library_versions` configuration options control how `ruby-bindgen` generates the library search logic.

### Library Names

`library_names` specifies the base names of the shared library. The generated code prepends `lib` and appends the platform-appropriate suffix:

| Platform | `library_names: ["proj"]` searches for              |
|----------|-----------------------------------------------------|
| Linux    | `libproj`, `libproj.so.{version}`                   |
| macOS    | `libproj`, `libproj.{version}.dylib`                |
| Windows  | `libproj`, `libproj-{version}`, `libproj_{version}` |

### Library Versions

C shared libraries use version suffixes that vary by platform and change across releases. `library_versions` lets you list known version suffixes so FFI can find whichever version is installed.

For example, the [PROJ](https://proj.org/) coordinate transformation library has used these version suffixes across releases:

```yaml
library_names:
  - proj
library_versions:
  - "25"    # PROJ 9.2
  - "22"    # PROJ 8.x
  - "19"    # PROJ 7.x
  - "17"    # PROJ 6.1, 6.2
  - "15"    # PROJ 6.0
```

This generates search names like `libproj.so.25`, `libproj.so.22`, etc. on Linux, `libproj.25.dylib` on macOS, and `libproj-25` on Windows. FFI tries each name in order until one succeeds. The unversioned `libproj` is always included as a fallback.

If `library_versions` is omitted, only the unversioned name is searched. This works on most systems where the package manager creates an unversioned symlink (e.g., `libproj.so` → `libproj.so.25`).

## Filtering

`ruby-bindgen` can filter which symbols are included in the generated bindings:

- [`skip_symbols`](configuration.md#skip-symbols) - Skip specific functions, structs, enums, or typedefs by name or regex pattern
- [`export_macros`](configuration.md#export-macros) - Only include functions marked with specific visibility macros

## Usage Tips

Since C is procedural rather than object-oriented, you may want to wrap the generated FFI bindings in Ruby classes to provide a more idiomatic API:

```ruby
require_relative 'generated/mylib'

class MyLibWrapper
  def initialize
    @handle = Mylib.create_handle()
  end

  def process(data)
    Mylib.process_data(@handle, data)
  end

  def close
    Mylib.destroy_handle(@handle)
  end
end
```
