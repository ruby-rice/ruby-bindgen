# C Bindings

`ruby-bindgen` generates Ruby files that use the [FFI](https://github.com/ffi/ffi) gem to call C library functions. FFI allows Ruby to directly load and call functions from C shared libraries without writing a C extension. This means:

- **No compilation step** - Ruby loads the library at runtime
- **Easier distribution** - No need to compile native code for each platform
- **Simpler development** - No C code to write or debug

If a library provides a C API then use it!

## Supported Features

`ruby-bindgen` supports the following FFI features:

- [Functions](https://github.com/ffi/ffi/wiki/Basic-Usage) via `attach_function`, including variadic functions (`:varargs`). Functions taking `va_list` parameters are skipped since `va_list` cannot be constructed from Ruby.
- [Structs](https://github.com/ffi/ffi/wiki/Structs) map to `FFI::Struct`
- Unions map to `FFI::Union`
- [Enums](https://github.com/ffi/ffi/wiki/Enums) map to FFI enum types
- [Callbacks](https://github.com/ffi/ffi/wiki/Callbacks) for function pointer types
- [Typedefs](https://github.com/ffi/ffi/wiki/Types) are preserved
- Forward declarations map to opaque pointer types
- Global variables via [`attach_variable`](https://www.rubydoc.info/gems/ffi/FFI/Library#attach_variable-instance_method)
- Constants from `const` variables (see [Constants and Macros](constants.md))

## Getting Started

See [Getting Started](getting_started.md) for a step-by-step guide to creating your first FFI bindings.

## Output

See [FFI Output](output.md) for details on the generated files.

## Examples

The test suite includes bindings generated from some popular C libraries:

| Library         | Description                       |
|-----------------|-----------------------------------|
| [PROJ](https://proj.org/)     | Coordinate transformation library |
| [SQLite](https://sqlite.org/)   | Database engine                   |
| [libclang](https://clang.llvm.org/) | C/C++ parsing library             |

See [test/headers/c](../../test/headers/c) for the input headers and [test/bindings/c](../../test/bindings/c) for the generated Ruby bindings.

## Ruby Wrapper Classes

Since C is procedural rather than object-oriented, you may wish to wrap the generated FFI bindings in Ruby classes to provide a more idiomatic API:

```ruby
require_relative 'generated/mylib_ffi'

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
