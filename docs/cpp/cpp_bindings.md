# C++ Bindings

`ruby-bindgen` creates Ruby bindings for C++ libraries using [Rice](https://github.com/ruby-rice/rice). Creating C++ bindings takes more work than creating C bindings, so if a library provides both a C and C++ API you should use the C API.

`ruby-bindgen` does its best to generate compilable Rice code. It has been battle tested against [OpenCV](https://github.com/opencv/opencv), which is a large, complex C++ API with over a thousand classes and ten thousand methods. 

For many libraries, the generated bindings will compile and work with no additional changes. For example, Rice includes a fully automated example binding for the [BitmapPlusPlus](https://ruby-rice.github.io/BitmapPlusPlus-ruby/) library.

For more complex libraries, like [OpenCV](https://github.com/opencv/opencv), some [customization](customizing.md) will likely be required.

## Getting Started

See [Getting Started](getting_started.md) for a step-by-step guide to creating your first Rice bindings.

## Output

See [Rice Output](output.md) for details on the generated files, including header files, project files, the include header, and the init function call graph.

## Build System

After generating Rice bindings, you will need to setup a build system for your extension. `ruby-bindgen` can generate [CMake build files](../cmake_bindings.md) to compile and link the generated bindings.

## Packaging

For packaging your extension as a gem, see the Rice [Packaging](https://ruby-rice.github.io/4.x/packaging/packaging/) documentation.

## Example

For a complete, fully automated example see [BitmapPlusPlus-ruby](https://ruby-rice.github.io/BitmapPlusPlus-ruby/).
