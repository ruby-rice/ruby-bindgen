# C++ Operators

C++ supports a lot of operators! These include operators that easily come to mind such as arithmetic and logical operators, as well as [conversion](https://en.cppreference.com/w/cpp/language/cast_operator) operators. It also includes obscure operators you probably do not use much (comma operator?).

Both C++ and Ruby support operator overriding, although C++ supports more of them. The sections below describe how to map C++ operators to Ruby operators.

C++ operators that are not supported by Ruby can be mapped to Ruby methods instead. By convention these methods are named based on the C++ operator name. Thus the C++ assign operator, `=`, is mapped to a Ruby method called assign.

```ruby
my_object1 = SomeClass.new
my_object2 = SomeClass.new
my_object1.assign(my_object2)
```

## Arithmetic Operators

C++ and Ruby support overriding the same arithmetic operators.

| C++ | Ruby |
|:---:|:----:|
| +   | +    |
| -   | -    |
| *   | *    |
| /   | /    |
| %   | %    |

## Unary Operators

C++ supports unary versions of `+`, `-`, `~`, and `!`. Ruby uses special method names for unary `+` and `-` to distinguish them from their binary counterparts.

| C++ | Ruby | Notes |
|:---:|:----:|:------|
| +a  | +@   | Unary plus |
| -a  | -@   | Unary minus (negation) |
| ~a  | ~    | Bitwise NOT |
| !a  | !    | Logical NOT |

### Member Unary Operators

```cpp
class Vector
{
public:
    Vector operator-() const;  // Unary minus
    Vector operator+() const;  // Unary plus
    Vector operator~() const;  // Bitwise NOT
};
```

Ruby-bindgen generates:

```cpp
define_method("-@", &Vector::operator-);
define_method("+@", &Vector::operator+);
define_method("~", &Vector::operator~);
```

### Non-Member Unary Operators

Non-member unary operators (common in libraries like OpenCV) are also supported:

```cpp
// Non-member unary operators
MatExpr operator~(const Mat& m);   // Bitwise NOT
MatExpr operator-(const Mat& m);   // Negation
MatExpr operator+(const Mat& m);   // Unary plus
```

Ruby-bindgen generates lambdas that call the C++ operator:

```cpp
rb_cMat.
    define_method("~", [](const Mat& self) -> MatExpr { return ~self; }).
    define_method("-@", [](const Mat& self) -> MatExpr { return -self; }).
    define_method("+@", [](const Mat& self) -> MatExpr { return +self; });
```

In Ruby:

```ruby
mat = Mat.new(rows, cols, type)
negated = -mat     # Calls -@ method
inverted = ~mat    # Calls ~ method
```

## Assignment Operators

C++ supports overriding assignment operators while Ruby does not. Thus these operators must be mapped to Ruby methods.

| C++  | Ruby             | Ruby Method     |
|:----:|:----------------:|:----------------|
| =    | Not overridable  | assign          |
| +=   | Not overridable  | assign_plus     |
| -=   | Not overridable  | assign_minus    |
| *=   | Not overridable  | assign_multiply |
| /=   | Not overridable  | assign_divide   |
| %=   | Not overridable  | assign_modulus  |

## Bitwise Operators

C++ and Ruby support overriding the same bitwise operators.

| C++ | Ruby |
|:---:|:----:|
| &   | &    |
| \|  | \|   |
| ^   | ^    |
| ~   | ~    |
| <<  | <<   |
| >>  | >>   |

## Bitwise Assignment Operators

C++ supports overriding bitwise assignment operators while Ruby does not. Thus these operators must be mapped to Ruby methods.

| C++  | Ruby             | Ruby Method        |
|:----:|:----------------:|:-------------------|
| &=   | Not overridable  | assign_and         |
| \|=  | Not overridable  | assign_or          |
| ^=   | Not overridable  | assign_xor         |
| <<=  | Not overridable  | assign_left_shift  |
| >>=  | Not overridable  | assign_right_shift |

## Comparison (Relational) Operators

C++ and Ruby support overriding the same comparison operators.

| C++ | Ruby |
|:---:|:----:|
| ==  | ==   |
| !=  | !=   |
| >   | >    |
| <   | <    |
| >=  | >=   |
| <=  | <=   |

## Logical Operators

Ruby allows the `!` operator to be overridden but not `&&` or `||`.

| C++    | Ruby             | Ruby Method |
|:------:|:----------------:|:------------|
| &&     | Not overridable  | logical_and |
| \|\|   | Not overridable  | logical_or  |
| !      | !                |             |

## Increment / Decrement Operators

C++ supports increment and decrement operators while Ruby does not. Thus these operators must be mapped to Ruby methods.

| C++  | Ruby             | Ruby Method    |
|:----:|:----------------:|:---------------|
| ++a  | Not overridable  | increment      |
| a++  | Not overridable  | increment_post |
| --a  | Not overridable  | decrement      |
| a--  | Not overridable  | decrement_post |

## Other Operators

C++ and Ruby support overriding an additional set of operators. The comma operator is not overridable in Ruby nor does it make sense to map it to a Ruby method.

| C++ | Ruby              | Ruby Method |
|:---:|:-----------------:|:------------|
| []  | []                |             |
|     | []= (if reference)|             |
| ()  | Not Overridable   | call        |
| *   | Not Overridable   | dereference |
| ->  | Not Overridable   | arrow       |
| <<  | <<                |             |
| >>  | >>                |             |
| ,   | Not overridable   |             |

If a C++ class defines an `[]` operator that returns a reference, then in it should be mapped to two Ruby operators: `[]` and `[]=`.

C++ classes that support the `()` operator are known as functors. Ruby supports overriding the `.()` operator by defining a `call` function. Note this isn't quite the same as C++ because it is invoked via `.()` and not `()` -- notice the `.` before the `()`.

## Non-Member Operators

C++ allows operators to be defined as non-member (free) functions. This is a common pattern for binary operators where the left operand determines the behavior:

```cpp
class Matrix {
public:
    int rows, cols;
};

// Non-member operators
Matrix& operator+=(Matrix& a, const Matrix& b);
Matrix& operator-=(Matrix& a, const Matrix& b);
Matrix& operator*=(Matrix& a, double scalar);
```

Ruby doesn't have the concept of non-member functions - all methods belong to a class. Therefore, ruby-bindgen automatically converts non-member operators to instance methods on the first argument's class:

```ruby
# Generated Ruby bindings
matrix1 = Matrix.new
matrix2 = Matrix.new

matrix1.assign_plus(matrix2)   # Calls operator+=(matrix1, matrix2)
matrix1.assign_multiply(2.0)   # Calls operator*=(matrix1, 2.0)
```

### Streaming Operators

The `<<` operator is commonly used for two different purposes in C++:

1. **Output streaming** (`std::ostream& operator<<(std::ostream&, const T&)`) - Used to print objects. Ruby-bindgen converts these to `inspect` methods on the streamed class.

2. **Other streaming** (e.g., `FileStorage& operator<<(FileStorage&, const T&)`) - Used for serialization or other purposes. Ruby-bindgen converts these to `<<` instance methods.

```cpp
// Output streaming - generates inspect method on Printable
std::ostream& operator<<(std::ostream& os, const Printable& p);

// FileStorage streaming - generates << method on FileStorage
FileStorage& operator<<(FileStorage& fs, const std::string& value);
FileStorage& operator<<(FileStorage& fs, int value);
FileStorage& operator<<(FileStorage& fs, const cv::Mat& mat);
```

The generated Ruby code groups all non-member operators by their target class:

```cpp
rb_cPrintable.
    define_method("inspect", [](const Printable& self) -> std::string
    {
      std::ostringstream stream;
      stream << self;
      return stream.str();
    });

rb_cFileStorage.
    define_method("<<", [](FileStorage& self, const std::string& other) -> FileStorage&
    {
      self << other;
      return self;
    }).
    define_method("<<", [](FileStorage& self, int other) -> FileStorage&
    {
      self << other;
      return self;
    });
```

## Conversion Operators

C++ allows users to define [conversion operators](https://en.cppreference.com/w/cpp/language/cast_operator) (also called cast operators or user-defined conversions). These enable a class instance to be implicitly or explicitly converted to another type. For example:

```cpp
class Money
{
public:
    Money(double amount) : amount_(amount) {}

    // Conversion to double - allows: double d = money_instance;
    operator double() const { return amount_; }

    // Conversion to bool - allows: if (money_instance) { ... }
    operator bool() const { return amount_ != 0.0; }

    // Conversion to string - allows: std::string s = money_instance;
    operator std::string() const { return std::to_string(amount_); }

private:
    double amount_;
};
```

Following Ruby conventions, conversion operators are mapped to `to_*` methods. This allows natural Ruby idioms:

```ruby
money = Money.new(42.50)
money.to_f      # => 42.5
money.to_bool   # => true
money.to_s      # => "42.500000"
```

### Conversion Type Mappings

The following table shows how C++ types map to Ruby method names and their corresponding Ruby classes:

| C++ Type | Ruby Method | Ruby Class |
|:---------|:------------|:-----------|
| `int` | `to_i` | `Integer` |
| `long` | `to_l` | `Integer` |
| `long long` | `to_i64` | `Integer` |
| `short` | `to_i16` | `Integer` |
| `unsigned int` | `to_u` | `Integer` |
| `unsigned long` | `to_ul` | `Integer` |
| `unsigned long long` | `to_u64` | `Integer` |
| `unsigned short` | `to_u16` | `Integer` |
| `int8_t` | `to_i8` | `Integer` |
| `int16_t` | `to_i16` | `Integer` |
| `int32_t` | `to_i32` | `Integer` |
| `int64_t` | `to_i64` | `Integer` |
| `uint8_t` | `to_u8` | `Integer` |
| `uint16_t` | `to_u16` | `Integer` |
| `uint32_t` | `to_u32` | `Integer` |
| `uint64_t` | `to_u64` | `Integer` |
| `size_t` | `to_size` | `Integer` |
| `float` | `to_f32` | `Float` |
| `double` | `to_f` | `Float` |
| `long double` | `to_ld` | `Float` |
| `bool` | `to_bool` | `TrueClass` / `FalseClass` |
| `std::string` | `to_s` | `String` |
| `const char*` | `to_s` | `String` |

### Notes

- **Integer types**: Ruby has a single `Integer` class that handles arbitrary precision. The different method names (`to_i`, `to_l`, `to_i64`, etc.) distinguish which C++ type is being converted, but all return Ruby `Integer` objects.

- **Floating point types**: Ruby's `Float` is a double-precision floating point number. The `to_f32` method converts from C++ `float` (single precision), while `to_f` converts from `double`. Both return Ruby `Float` objects.

- **Custom types**: Conversion operators to custom C++ types (classes, structs) are mapped to `to_<typename>` methods where the type name is converted to snake_case. For example, `operator MyClass()` becomes `to_my_class`.

- **Pointer conversions**: Conversion operators returning pointers (`operator T*()`) are mapped to `to_ptr` or `to_const_ptr` methods.
