# Classes & Structs

`ruby-bindgen` generates Rice bindings for C++ classes and structs, including constructors, methods, member variables, and single inheritance. For details on how Rice wraps classes, see the Rice documentation on [Classes](https://ruby-rice.github.io/4.x/bindings/classes/), [Constructors](https://ruby-rice.github.io/4.x/bindings/constructors/), [Methods](https://ruby-rice.github.io/4.x/bindings/methods/), [Overloaded Methods](https://ruby-rice.github.io/4.x/bindings/overloaded_methods/), [Attributes](https://ruby-rice.github.io/4.x/bindings/attributes/), and [Constants](https://ruby-rice.github.io/4.x/bindings/constants/).

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

## Single Inheritance

```cpp
class Derived : public Base {};
```

Generates:
```cpp
define_class<Derived, Base>("Derived")
```

For template base class inheritance, see [Templates](templates.md#template-base-classes).

## Methods

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

For a complete table of conversion type mappings, see the [Operators](operators.md#conversion-operators) page.

### Callbacks

`ruby-bindgen` understands C-style callbacks and generates the appropriate Rice [callback code](https://ruby-rice.github.io/4.x/bindings/callbacks/).

### Safe Bool Idiom

Pre-C++11 "safe bool idiom" using typedef to member function pointer is automatically skipped:

```cpp
typedef void (MyClass::*bool_type)() const;
operator bool_type() const;  // Skipped
```

### Default Values

`ruby-bindgen` preserves C++ default parameter values, handling namespace qualification and type constraints.

Default values are automatically qualified with full namespace paths:

```cpp
void func(int flags = NORM_L2);           // -> cv::NORM_L2
void func(Mat m = noArray());             // -> cv::noArray()
void func(Scalar s = Scalar::all(0));     // -> cv::Scalar::all(0)
```

Default values referencing class template members preserve template parameters:

```cpp
template<typename T>
class Quat {
    static constexpr T EPS = 1e-6;
    Quat(T eps = EPS);  // -> cv::Quat<T>::EPS
};
```

Default parameter values are only generated for copyable types. `ruby-bindgen` detects non-copyable types via private copy constructors, deleted copy constructors (`= delete`), or inherited inaccessible copy constructors:

```cpp
class NonCopyable {
    NonCopyable(const NonCopyable&) = delete;
};

void func(NonCopyable nc = NonCopyable());  // Default value NOT generated
```
