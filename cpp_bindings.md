# C++ Bindings
`ruby-bindgen` creates C++ bindings using [Rice](https://github.com/ruby-rice/rice). This is necessary for creating bindings for libraries that only provide a C++ API, such as [OpenCv](https://github.com/opencv/opencv). In fact, `ruby-bindgen` was specifically developed to help create bindings for OpenCV since it such a large project.

C++ is a complex language, so do not expect the generated bindings to work as-is - they will undoubtedly require significant work after being generated to get compiling and working. However, for large libraries, generating the bindings can save weeks, if not months, worth of work.

## Features
`ruby-bindgen` has almost complete support for C++, including:

* Classes/Structs
  * Static member functions
  * Static member fields
  * Member functions
  * Member fields
  * Nested classes, structs, unions and enums
  * Inheritance
* Methods
  * Default parameter values
  * Overloading
  * Argument annotation
* Templates (class)
* Callbacks
  * C-Style

## Generated Files
Most C++ APIs consist of a number of header files. To use a concrete example, assume we want to create a Ruby extension called `MyExtension` from a set of five C++ header files. When you run `ruby-bindgen` it will generate the following files:

* For every C++ header file, two Rice files are created, a .hpp and .cpp file. These files have the same name as the C++ header but with the addition of `-rb` at the end. For example, a C++ header file called `Matrix.hpp` will result in `Matrix-rb.hpp` and `Matrix-rb.cpp`. These files will declare and define an `Init_` function, in this example `Init_Matrix`, which will include the appropriate Rice definitions.

* Two files are created for the extension. These files are named after the extension, so in this case `MyExtension-rb.hpp` and `MyExtension-rb.cpp`. The `MyExtension-rb.hpp` file declares the main Ruby init function called `Init_MyExtension` and `MyExtension-rb.cpp` files defines it. The `Init_MyExtension` function will invoke the `Init_` function in the generated files described above (so `Init_Matrix`).

* A `MyExtension.def` file that is used to export the `Init_MyExtension` from the Ruby extension on Windows

So for a C++ library with 5 header files, `ruby-bindgen` will generate 13 wrapper files.

## Naming Conventions
`ruby-bindgen` follow Ruby naming conventions. Thus, it will convert C++ names to their appropriate Ruby names. That means UpperCase for class names, CAPITALIZED for constants, under_score for functions, etc.

## C++ Classes and Structs
C++ classes and structs are mapped to Ruby classes. `ruby-bindgen` supports:

* Static member fields (Rice [attributes](https://ruby-rice.github.io/4.x/bindings/attributes.html))
* Static member functions (Rice [methods](https://ruby-rice.github.io/4.x/bindings/methods.html))
* Member fields (Rice [attributes](https://ruby-rice.github.io/4.x/bindings/attributes.html))
* Member functions (Rice [methods](https://ruby-rice.github.io/4.x/bindings/methods.html))
* Nested classes, structs and enums

### Constructors
Rice requires that constructor arguments are fully specified. For example, using the `Mat` class from OpenCV:

```C++  
  rb_cCvMat = define_class_under<cv::Mat>(rb_mCv, "Mat").
    define_constructor(Constructor<cv::Mat>()).
    define_constructor(Constructor<cv::Mat, int, int, int>(),
      Arg("rows"), Arg("cols"), Arg("type"))
```

`ruby-bingden` will generate two `define_constructor` calls, specify the parameter types as well as their names. 

### Attributes
Both getter and setter attributes are supported. See [attributes](https://ruby-rice.github.io/4.x/bindings/attributes.html).

### Methods
C++ methods support overloading. `ruby-bindgen` automatically determines which methods are overloaded and which are not:

```C++  
    define_method("col", &cv::Mat::col,
      Arg("x")).
    define_method<cv::Mat(cv::Mat::*)(int, int) const>("row_range", &cv::Mat::rowRange,
      Arg("startrow"), Arg("endrow")).
    define_method<cv::Mat(cv::Mat::*)(const cv::Range&) const>("row_range", &cv::Mat::rowRange,
      Arg("r")).
```

In the example above, the `col` method only requires a member function pointer (`&cv::Mat::col`) but the overloaded methods also need to specify their parameters `<cv::Mat(cv::Mat::*)(int, int) const>` so the C++ compiler can disambiguate them. Once again, `ruby-bindgen` does this automatically.

### Default Arguments
C++ methods support default arguments. These are mapped to Rice [arguments](https://ruby-rice.github.io/4.x/bindings/methods.html#default-arguments). However, setting default values is tricky. For example, the OpenCV `GpuMat` class has this constructor:

```C++
    GpuMat(GpuMat::Allocator* allocator = GpuMat::defaultAllocator());
```

But for this to work with Rice it needs to be mapped this code:

```C++
    define_constructor(Constructor<cv::cuda::GpuMat, cv::cuda::GpuMat::Allocator*>(),
      Arg("allocator") = static_cast<cv::cuda::GpuMat::Allocator *>(cv::cuda::GpuMat::defaultAllocator())).
```
Notice that `ruby-bindgen` has added namespace information, `cv::cuda::`.

And that is what makes default arguments tricky. `libclang` does not provide great information about default arguments via its API, so `ruby-bindgen` does its best to figure out the proper namespacing. That gets especially tricky with C++ templates. This is the part of the generated bindings that requires the most manual post processing to get them to compile.

## C++ Enums
C++ styles enums, called enum classes, are mapped to Rice Enums. C style enums are also mapped to [Rice Enums](https://ruby-rice.github.io/4.x/bindings/enums.html), unless they are anonymous. In that case the C style enum is mapped to a set of Ruby constants. For examples, see [test/headers/cpp/enum.hpp](test/headers/cpp/enum.hpp) and [test/bindings/cpp/enum-rb.cpp](test/bindings/cpp/enum-rb.cpp).

## Callbacks
`ruby-bindgen` understands C style callbacks, and will generate the appropriate Rice [callback code](https://ruby-rice.github.io/4.x/bindings/callbacks.html).

## C++ Operators
C++ and Ruby both support operator overriding. `ruby-bindgen` maps C++ operators to Ruby operators as described in the Rice [operator](https://ruby-rice.github.io/4.x/bindings/operators.html) documentation.

Operators that require special handling include:

* `[]`
* `()`
* Conversion functions

The C++ `operator[]()` is mapped two Ruby operators - `[]` and `[]=` if the return value is a reference. Otherwise, it is only mapped to `[]`.

The C++ `operator()()` is mapped to Ruby `call`. This allows the method to be invoked using the admittedly weird syntax of `.()`. Or of course you could just use `call`.

C++ conversion functions are mapped to `to_<some_type>` - for example `to_i` or `to_f` or `to_matrix`, etc. 

## Examples
The [test/headers/cpp](test/headers/cpp) folder contains example of C++ header files. The generated bindings are in the [test/bindings/cpp](test/bindings/cpp) folder. The [rice_test](test/rice_test.rb) file shows how the bindings are generated.
