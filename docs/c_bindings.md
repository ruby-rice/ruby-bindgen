# C Bindings

C bindings are created using [FFI](https://github.com/ffi/ffi) (Foreign Function Interface). FFI allows Ruby to directly load and call functions from C shared libraries without writing a C extension. This means:

- **No compilation step** - Ruby loads the library at runtime
- **Easier distribution** - No need to compile native code for each platform
- **Simpler development** - No C code to write or debug

## What to Expect

ruby-bindgen generates FFI bindings that handle the work of mapping C types to Ruby. The generated code should work directly with your C library.

## Supported Features

ruby-bindgen supports:

- **Functions** - C functions mapped to Ruby module methods via `attach_function`
- **Structs** - C structs mapped to `FFI::Struct` classes with proper layouts
- **Unions** - C unions mapped to `FFI::Union` classes
- **Enums** - C enums mapped to FFI enum types
- **Callbacks** - Function pointer types for C callbacks
- **Typedefs** - Type aliases preserved in the generated code
- **Forward declarations** - Opaque struct types handled correctly
- **Global variables** - Exported variables via `attach_variable`

## Generated Output

For each C header file, ruby-bindgen generates a Ruby file with the same name. The generated file:

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

## Naming Conventions

ruby-bindgen follows Ruby naming conventions:

- Module names: `UpperCamelCase` (from library name)
- Struct/Union names: `UpperCamelCase`
- Function names: `snake_case`
- Enum values: `snake_case` symbols

## Real-World Examples

The test suite includes bindings generated from real C libraries:

| Library | Description |
|---------|-------------|
| [PROJ](https://proj.org/) | Coordinate transformation library |
| [SQLite](https://sqlite.org/) | Database engine |
| [libclang](https://clang.llvm.org/) | C/C++ parsing library |

See [test/headers/c](../test/headers/c) for the input headers and [test/bindings/c](../test/bindings/c) for the generated Ruby bindings.

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
