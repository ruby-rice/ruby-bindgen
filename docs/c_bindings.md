# C Bindings
C bindings are created using [FFI](https://github.com/ffi/ffi). The huge advantage of using FFI to create extensions is that it enables Ruby to directly load C libraries. There is no need to write a C extension, which can take a significant amount of time. In addition, there is no compile step which makes distributing your extension as a Gem much easier.

`ruby-bindgen` supports:

* C functions
* C structs, unions and enums
* Nested structs, unions and enums
* Forward declarations
* Callbacks

## Ruby Methods
`ruby-bindgen` generates Ruby methods that directly call C methods via FFI. Each C header file is mapped one-to-one to a Ruby file that includes the FFI definitions.

Since C is a procedural, non-object oriented language it is likely you will want to group related API calls together into Ruby classes to provide a more friendly Ruby API.

## Naming Standards
`ruby-bindgen` follow Ruby naming conventions. Thus it will convert C function names to underscored name (ie, `someFunction` -> `some_function`) and will start structs and unions with capital letters.

## Examples
The [test/headers/c](test/headers/c) folder contains example of C header files from [proj](https://github.com/OSGeo/PROJ), [sqlite3](https://github.com/sqlite/sqlite), [clang](https://github.com/llvm/llvm-project). The generated bindings are in the [test/bindings/c](test/bindings/c) folder. The [ffi_test](test/ffi_test.rb) file shows how the bindings are generated.
