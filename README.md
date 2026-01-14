# ruby-bindgen

Automatically generate Ruby bindings from C and C++ header files.

Writing Ruby bindings for C++ libraries by hand is tedious and error-prone. A library like OpenCV has thousands of classes, methods, and functions. Creating bindings manually would take months of work and be difficult to maintain as the library evolves. ruby-bindgen automates this process, turning weeks of work into hours.

## Ecosystem

ruby-bindgen is part of a toolchain for wrapping C++ libraries for Ruby:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            C++ Library                                  │
│                         (headers + source)                              │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Clang / ffi-clang                               │
│                        (parse C++ headers)                              │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           ruby-bindgen                                  │
│                    (generate Rice binding code)                         │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                              Rice                                       │
│            (type conversion, memory management, introspection)          │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         CMake / Build System                            │
│                        (compile the extension)                          │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            Ruby Gem                                     │
│                    (compiled extension + RBS types)                     │
└─────────────────────────────────────────────────────────────────────────┘
```

### How It Works

1. **[Clang](https://clang.llvm.org/)** provides libclang, a library for parsing C++ code
2. **[ffi-clang](https://github.com/ioquatix/ffi-clang)** exposes libclang to Ruby, enabling AST traversal
3. **ruby-bindgen** walks the AST and generates [Rice](https://github.com/ruby-rice/rice) binding code
4. **[Rice](https://github.com/ruby-rice/rice)** handles type conversion, memory management, and Ruby integration
5. **CMake** compiles the extension into a loadable Ruby gem

## Binding Formats

ruby-bindgen supports two output formats:

| Format | Library | Use Case |
|--------|---------|----------|
| **Rice** | [Rice](https://github.com/ruby-rice/rice) | C++ libraries |
| **FFI** | [FFI](https://github.com/ffi/ffi) | C libraries |

If a library provides both C and C++ APIs, prefer the C API. It's simpler to wrap and more stable across releases.

- [C++ Bindings Documentation](docs/cpp_bindings.md)
- [C Bindings Documentation](docs/c_bindings.md)

For complete documentation, see the [docs](docs/index.md) folder.

After generating bindings, see Rice's [CMake guide](https://ruby-rice.github.io/4.x/packaging/cmake/) for building your extension.

## Installation

Install ffi-clang

```console
$ git clone https://github.com/ioquatix/ffi-clang && cd ffi-clang
$ bundle config set --local with maintenance && bundle exec bake gem:install
```

Install ruby-bindgen

```console
$ git clone https://github.com/ruby-rice/ruby-bindgen.git && cd ruby-bindgen
$ rake install
```

## Usage

ruby-bindgen includes a command line tool called `ruby-bindgen` which is used to create new bindings. Its usage is:

```
ruby-bindgen [options] input -- [clang options (see clang documentation)]
```

```
Options include:
  -e, --extension Name of the generated Ruby extension (C++ only). Must be a valid C++ identifier
  -i, --input     Path to input directory that includes header files
  -o, --output    Path to output directory
  -m, --match     Glob pattern to match header files
  -s, --skip      Glob pattern to skip header files. May be specified multiple times
  -f, --format    Type of bindings to generate. Valid values are `FFI` and `Rice`.
  -h, --help      Shows this help message
```

## Example
Ruby Bindgen was used to create C++ bindings for the [OpenCV](https://github.com/opencv/opencv) library. OpenCV is a big library, so it provides a good example of using `ruby-bindgen`. The bindings were originally generated on Windows using [vcpkg](https://vcpkg.io/en/) and [Visual Studio](https://visualstudio.microsoft.com/), but the below command works just as well on MacOS and Linux (requires changing path of course).

The command line is:

```
./ruby-bindgen --extension ruby-opencv \
               --input C:\Source\vcpkg\installed\x64-windows\include\opencv4 \
               --match opencv2/**/*.{h,hpp} \
               --skip opencv2/core/opencl/**/* \
               --skip opencv2/cudalegacy/**/*.hpp \
               --skip opencv2/**/*.inl* \
               --output C:\Source\ruby-opencv\ext\opencv \
               --format Rice \
               -- \
               "-IC:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.42.34433\include" \
               "-IC:\\Program Files (x86)\\Windows Kits\\10\\include\\10.0.22621.0\\ucrt" \
               "-IC:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\Llvm\lib\clang\17\include" \
               "-IC:\Source\vcpkg\installed\x64-windows\include\opencv4" \
               -xc++
```
The command line creates a new C++ Ruby extension called `ruby-opencv`. `OpenCV` has a complicated headers layout, with the root directory located at `https://github.com/opencv/opencv/tree/4.x/include`. This is what the `--input` parameter points to.

Next, process all *.h and *.hpp header files in any subdirectories under the input directory:

```
--match opencv2/**/*.{h,hpp} \
```

Then we want to skip various header files that should not be processed:

```
--skip opencv2/core/opencl/**/* \
--skip opencv2/cudalegacy/**/*.hpp \
--skip opencv2/**/*.inl* \
```

Output should be written the following directory:

```
--output C:\Source\ruby-opencv\ext\opencv \
```

Note the output folder directory structure will match the input directory structure - `ruby-bindgen` will automatically create the necessary sub directories.

Next, we want to generate C++ bindings using Rice:

```
--format Rice
```

Finally, we want to set a bunch of Clang compiler options so it can find the correct header files to process:

```
   "-IC:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.42.34433\include" \
   "-IC:\\Program Files (x86)\\Windows Kits\\10\\include\\10.0.22621.0\\ucrt" \
   "-IC:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\Llvm\lib\clang\17\include" \
   "-IC:\Source\vcpkg\installed\x64-windows\include\opencv4" \
   -xc++
```

## Similar Work

- [ffi_gen](https://github.com/ffi/ffi_gen) - Unmaintained bindings generator for C
- [rbind](https://github.com/D-Alex/rbind) - Gem with custom C++ parser
- [Magnus](https://github.com/matsadler/magnus) - Bindings generator for Rust
