# ruby-bindgen
RubyBindgen generates Ruby bindings from C and C++ header files. To do this it uses [libclang](https://clang.llvm.org/doxygen/group__CINDEX.html), via the [ffi-clang](https://github.com/ioquatix/ffi-clang) gem, to parse header files. It then traverses the Clang AST using the visitor patter.

Two visitors are implemented - one for C that generates [FFI](https://github.com/ffi/ffi) bindings and one for C++ that generates [Rice](https://github.com/ruby-rice/rice) bindings.

If a library provides both a C and C++ API, use the C API! It will likely be much easier to develop a Ruby extension using the C API and will also likely be more stable between releases.

## C Bindings
C bindings are created using [FFI](https://github.com/ffi/ffi). For more information see the [C bindings](c_bindings.md) documentation.

## C++ Bindings
C++ bindings are created using [Rice](https://github.com/ruby-rice/rice). For more information see the [C++ bindings](cpp_bindings.md) documentation.

## Installation

Install ffi-clang

```console
$ git clone https://github.com/ioquatix/ffi-clang && cd ffi-clang
$ bundle config set --local with maintenance && bundle exec bake gem:install
```

Install ruby-bingen

```console
$ git clone https://github.com/ruby-rice/ruby-bindgen.git && cd ruby-bindgen
$ rake install
```

## Usage
ruby-bindgent includes a command line tool called `ruby-bidgen` which is used to create new bindings. Its usage is:

```
ruby-bindgen [options] input -- [clang options (see clang documnetation)]
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
./ruby-bindgen --extens ruby-opencv \
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

Next, process all *.hpp and *.hpp header files in any subdirectories under the input directory:

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
[ffi_gen](https://github.com/ffi/ffi_gen). Unmaintained bindings generator for C.
[rbing](https://github.com/D-Alex/rbind). Gem with custom C++ parser
[Magnus](https://github.com/matsadler/magnus). Bindings generator for Rust.
