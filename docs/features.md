# Features

Ruby-bindgen automatically handles many complex C++ patterns when generating Rice bindings. This page documents the supported features and how they're handled.

## Type Handling

### Template Classes and Specializations

Ruby-bindgen generates bindings for template class instantiations created via `typedef` or `using` statements:

```cpp
template<typename T> class Point_ { T x, y; };
typedef Point_<int> Point2i;
using Point2f = Point_<float>;
```

Generated bindings correctly handle:
- Fully qualified template arguments (`cv::Point_<int>` not `Point_<int>`)
- Base class inheritance chains for templates
- Auto-generation of base class bindings when no typedef exists

### Template Argument Qualification

Unqualified type names in template arguments are automatically qualified:

```cpp
// Input: std::map<String, DictValue>::iterator
// Output: std::map<cv::String, cv::dnn::DictValue>::iterator
```

### Smart Pointers

Custom smart pointer types (like `cv::Ptr<T>`) can be supported via the `include:` configuration option. Create a header with a `Rice::detail::Type<T>` specialization and all translation units will see it, preventing ODR violations.

### Incomplete Types (Pimpl Pattern)

Methods returning pointers or references to forward-declared types are automatically skipped:

```cpp
class MyClass {
    class Impl;  // Forward declaration
    Impl* getImpl();      // Skipped - returns pointer to incomplete type
    Impl& getImplRef();   // Skipped - returns reference to incomplete type
};
```

### Non-Copyable Types

Default parameter values are only generated for copyable types. Ruby-bindgen detects:

- **C++03 style**: Private copy constructor
- **C++11 style**: Deleted copy constructor (`= delete`)
- **Inherited**: Base class with inaccessible copy constructor

```cpp
class NonCopyable {
    NonCopyable(const NonCopyable&) = delete;
};

void func(NonCopyable nc = NonCopyable());  // Default value NOT generated
```

### std:: Typedefs

Typedefs to `std::` types are skipped since Rice handles them automatically:

```cpp
typedef std::string String;  // Skipped - Rice handles std::string
```

## Method Handling

### Overloaded Methods

Overloaded methods are automatically detected and generate explicit type signatures:

```cpp
void process(int x);
void process(double x);
```

Generates:
```cpp
define_method<void(MyClass::*)(int)>("process", &MyClass::process, Arg("x")).
define_method<void(MyClass::*)(double)>("process", &MyClass::process, Arg("x"));
```

### Conversion Operators

Type conversion operators generate appropriately named Ruby methods:

```cpp
operator bool() const;           // to_bool
operator std::string() const;    // to_std_string
operator int*();                 // to_ptr (non-const)
operator const int*() const;     // to_const_ptr
```

Template parameter conversions in class templates use generic names (`to_ptr`, `to_const_ptr`) to avoid invalid method names.

### Safe Bool Idiom

Pre-C++11 "safe bool idiom" using typedef to member function pointer is automatically skipped:

```cpp
typedef void (MyClass::*bool_type)() const;
operator bool_type() const;  // Skipped
```

### Iterator Methods

Iterator methods (`begin`, `end`, `rbegin`, `rend`) generate Rice `define_iterator` calls:

```cpp
iterator begin();
iterator end();
const_iterator begin() const;
```

Generates `each` and `each_const` methods in Ruby.

For iterators missing `std::iterator_traits`, ruby-bindgen generates the required trait specializations automatically.

### Non-Member Operators

Non-member operators are wrapped as instance methods on the first argument's class:

```cpp
Matrix operator+(const Matrix& a, const Matrix& b);
std::ostream& operator<<(std::ostream& os, const Matrix& m);
```

The `operator<<` with `ostream` generates an `inspect` method.

## Enum Handling

### Scoped Enums (enum class)

```cpp
enum class Color { Red, Green, Blue };
```

Generates a Rice enum with properly scoped values.

### Unscoped Enums

Unscoped enums in namespaces have values at namespace scope:

```cpp
namespace cv {
    enum BorderType { BORDER_CONSTANT, BORDER_REPLICATE };
}
// Values are cv::BORDER_CONSTANT, not cv::BorderType::BORDER_CONSTANT
```

Unscoped enums inside classes have values qualified with the enum name:

```cpp
class Buffer {
    enum Target { ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER };
};
// Values are Buffer::Target::ARRAY_BUFFER
```

## Default Values

### Qualified Names

Default values are automatically qualified with full namespace paths:

```cpp
void func(int flags = NORM_L2);           // -> cv::NORM_L2
void func(Mat m = noArray());             // -> cv::noArray()
void func(Scalar s = Scalar::all(0));     // -> cv::Scalar::all(0)
```

### Template Member Defaults

Default values referencing class template members preserve template parameters:

```cpp
template<typename T>
class Quat {
    static constexpr T EPS = 1e-6;
    Quat(T eps = EPS);  // -> cv::Quat<T>::EPS
};
```

### Global Namespace Items

Items in the global namespace (like `stdout`) are not prefixed with `::` to avoid breaking macros:

```cpp
void print(FILE* f = stdout);  // stdout, not ::stdout
```

## Filtering

### Export Macros

Only wrap functions marked with specific macros:

```yaml
export_macros:
  - CV_EXPORTS
  - CV_EXPORTS_W
```

### Skip Symbols

Skip specific symbols by name, qualified name, or regex:

```yaml
skip_symbols:
  - internalFunc                    # Simple name
  - cv::internal::helper            # Qualified name
  - /cv::dnn::.*Layer::init.*/      # Regex pattern
```

### Automatic Skipping

The following are automatically skipped:

- **Deprecated**: Functions with `__attribute__((deprecated))`
- **Internal**: Functions ending with underscore (`func_`)
- **Variadic**: Functions with `...` parameters
- **Deleted**: Methods marked `= delete`
- **Private/Protected**: Non-public members
- **Anonymous namespaces**: Internal implementation details

## Namespace Handling

### Inline Namespaces

Versioned inline namespaces (like `cv::dnn::dnn4_v20241223`) are handled transparently.

### Linkage Specifications

`extern "C"` blocks don't affect qualified names:

```cpp
extern "C" {
    typedef unsigned short ushort;  // Correctly qualified, not "::::ushort"
}
```

### Anonymous Namespaces

Anonymous namespaces are skipped entirely - they contain internal implementation details with internal linkage.

## Inheritance

### Single Inheritance

```cpp
class Derived : public Base {};
```

Generates:
```cpp
define_class<Derived, Base>("Derived")
```

### Template Base Classes

When a class inherits from a template instantiation, the base class binding is auto-generated if no typedef exists:

```cpp
class PlaneWarper : public WarperBase<PlaneProjector> {};
// Auto-generates WarperBasePlaneProjector binding
```

### Inheritance Chain Resolution

For template typedefs with base classes, the entire inheritance chain is resolved and generated in the correct order.

## Include Header

The `include:` configuration option specifies a custom header included by all generated files. This:

- Centralizes Rice includes
- Prevents ODR violations with template specializations
- Enables precompiled header optimization

See [Configuration](configuration.md#include-header) for details.

## Constructors

### Multiple Constructors

All public, non-deleted, non-deprecated constructors are wrapped:

```cpp
class MyClass {
    MyClass();
    MyClass(int x);
    MyClass(int x, int y);
};
```

### Implicit Default Constructor

If a class has no explicit constructors, the implicit default constructor is wrapped.

### Skipped Constructors

- Move constructors
- Deleted constructors
- Deprecated constructors
- Constructors of abstract classes

## Attributes

### Public Member Variables

Public member variables generate getter/setter methods via `define_attr`:

```cpp
class Point {
public:
    int x, y;  // Generates x, x=, y, y=
};
```

### Static Member Variables

Static members on classes use `define_singleton_attr`.

### Constants

`const` qualified variables and namespace-level variables generate Ruby constants.

## Generated File Names

### Init Function Names

Each generated file has an `Init_` function. To avoid conflicts when multiple files have the same name in different directories (e.g., `core/version.hpp` and `dnn/version.hpp`), the function name includes the directory path:

| File Path | Init Function |
|-----------|---------------|
| `version.hpp` | `Init_Version` |
| `core/version.hpp` | `Init_Core_Version` |
| `dnn/version.hpp` | `Init_Dnn_Version` |
| `core/hal/interface.hpp` | `Init_Core_Hal_Interface` |

The top-level directory is always removed to avoid overly long names (e.g., `opencv2/calib3d.hpp` becomes `Init_Calib3d`, and `opencv2/core/version.hpp` becomes `Init_Core_Version`).
