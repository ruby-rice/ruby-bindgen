# ruby-bindgen

Wrapping C and C++ libraries by hand for use in Ruby has traditionally been a long, arduous task. For large, complex libraries it can take months. As a result, many C/C++ libraries are either never exposed to Ruby or their bindings quickly become outdated, especially in scientific and technical domains.

`ruby-bindgen` solves this problem by automatically creating bindings from C and C++ header files. It can even generate a CMake build system if needed. It has been battle-tested against large C/C++ libraries such as Proj and OpenCV.

For much more information, read the extensive [documentation](https://ruby-rice.github.io/ruby-bindgen/).

## Quick Start

Create a config file (`rice-bindings.yaml`):

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

Generate bindings:

```bash
ruby-bindgen rice-bindings.yaml
```

This produces `.cpp`, `.hpp`, and `.ipp` files ready to compile as a Ruby extension.

## Install

```console
gem install ruby-bindgen
```

## Requirements

- Ruby 3.2+
- libclang (provided by LLVM/Clang)

## Documentation

Full documentation is at [ruby-rice.github.io/ruby-bindgen](https://ruby-rice.github.io/ruby-bindgen/).

- [C++ (Rice) Getting Started](https://ruby-rice.github.io/ruby-bindgen/cpp/getting_started/)
- [C (FFI) Getting Started](https://ruby-rice.github.io/ruby-bindgen/c/getting_started/)
- [Configuration Reference](https://ruby-rice.github.io/ruby-bindgen/configuration/)

## License

BSD-2-Clause
