# Customizing Bindings

`ruby-bindgen` tries its best to generate compilable Rice code. It has been battle tested against [OpenCV](https://github.com/opencv/opencv), which is a large, complex C++ API with over a thousand classes and ten thousand methods.

However, complex libraries may require some customization. Customizations fall into three categories:

* Configuration
* Refinements
* Fixes

## Configuration

Some issues are best solved via the [configuration](../configuration.md) file rather than editing generated code:

- Skip symbols: Functions that cause linker errors or aren’t meant for external use can be added to [`skip_symbols`](../configuration.md#skip-symbols)
- Export macros: Use [`export_macros`](../configuration.md#export-macros) to limit bindings to exported symbols, preventing linker errors from internal functions

## Refinements

Ruby classes are open, meaning you can reopen an existing class and add methods to it. Refinements take advantage of this to extend generated bindings with additional functionality. Note this is not quite the same as Ruby's [refinements](https://docs.ruby-lang.org/en/master/syntax/refinements_rdoc.html) functionality since which are scoped — these additions are global.

Common reasons to add refinements include:

| Addition                | What It Adds                                             |
|-------------------------|----------------------------------------------------------|
| Expected methods        | `inspect`, `to_s`                                        |
| Modules                 | `include_module(rb_mComparable)`, `define_method("<=>")` |
| Template instantiations | `Mat<unsigned char>`                                     |
| Type conversions        | `to_*`                                                   |
| Exceptions              | Custom exception class hierarchy                         |
| Custom type handling    | `Type<T>`, `From_Ruby<T>`, and `To_Ruby<T>`              |
| Custom STL names        | `define_vector<cv::Vec3b>(...)`                          |
| Non-member operators    | `+`, `-`, `*`, `/`, `==`                                 |
| Iteration               | Add `std::iterator_types`                                |
| Method renames          | `rb_alias` to rename methods to match Ruby idioms        |

Just like in Ruby, you can take advantage of Ruby’s open classes to add new functionality.

To do this, create a directory to contain additions. The directory can be named anything, but a suggested convention is to name it `refinements`. Here is an example layout:

```
ext/
├── myextension           # Generated files
│   ├── matrix-rb.hpp
│   ├── matrix-rb.hpp
│   └── ...
├── refinements/          # Manual additions (never overwritten)
│   ├── CMakeLists.txt
│   ├── matrix-rb.hpp     # to_s, template instantiations
│   ├── matrix-rb.cpp     # to_s, template_instantiations
│   └── ...
└── myextension-rb.cpp    # Main init file, calls Init_*_Refinements()
```

Create a new file in refinements for each generated Rice file you want to override. For example, if you want to add functionality to `matrix-rb.cpp`, then create `refinements/matrix-rb.hpp` and `refinements/matrix-rb.cpp`. As part of those files, define a new init function called `Init_Matrix_Refinements`.

Next add the .cpp file to `refinements/CMakeLists.txt`:
   ```cmake
   target_sources(${CMAKE_PROJECT_NAME} PRIVATE
                 "matrix-rb.cpp")
   ```
Then in the main `Init_MyExtension` function in the project `my_extension-rb.cpp` file, include the header and call the `Init_Matrix_Refinements` method.

Using refinements has a lot of advantages:

- Regeneration Safe: Your updates will not be overwritten with the exception of the `my_extension-rb.cpp` file
- Reuse `_instantiate` methods - Refinements can `#include` generated `.ipp` files to call [`_instantiate` functions](templates.md#template-instantiate-files-ipp) with new type arguments.

### Example

Here is an example `refinements/matrix-rb.cpp` refinements file:

```cpp
#include <matrix>
#include "matrix-rb.hpp"                    // Generated header
#include "../ext/matrix-rb.ipp"    // Generated _instantiate functions

using namespace Rice;

void Init_Matrix_Refinements()
{
  // Reopen the class that was already defined by generated code
  Rice::Data_Type<Matrix> matrix;

  matrix.
    define_method("to_s", [](const Matrix& self) -> std::string
    {
      std::ostringstream stream;
      stream << self;
      return stream.str();
    });

  // Rename a method to better match Ruby idioms
  rb_alias(matrix, rb_intern("[]"), rb_intern("call"));

  // Instantiate additional templates not in the generated code
  Matrix_instantiate<double>(rb_mMyExtensin, "MatrixDouble");
}
```

## Fixes

Sometimes you need to **modify** the generated Rice code. Common reasons include:

| Change Type       | Example                         | Why                                                                                    |
|-------------------|---------------------------------|----------------------------------------------------------------------------------------|
| Missing includes  | `#include <core.hpp>` | Generated file references types from headers it doesn't include                        |
| Version guards    | `#if VERSION >= 2`              | API only available in certain library versions                                         |
| Default values    | Remove `Stream::Null()` default | Avoid hardware-dependent functions such as CUDA initialization                         |

- Mark manual changes with `// Manual` comments so they're searchable: `grep -r "// Manual" ext/`
- Include order matters: System/library headers should come before the primary header, local project headers after
- Watch fluent chain syntax when commenting out methods: change the preceding `.` to `;` to terminate the chain
- Refinements can include generated `.ipp` files to reuse `_instantiate` functions with additional type arguments

If you have manual edits, you'll will need a strategy for preserving them when you [regenerate bindings](../updating_bindings.md).
