# Operators

`ruby-bindgen` automatically generates Rice bindings for C++ operators, mapping them to Ruby methods. For the complete C++ to Ruby operator mapping tables, see the Rice [Operators](https://ruby-rice.github.io/4.x/bindings/operators/) documentation.

## Non-Member Operators

C++ allows operators to be defined as non-member (free) functions. Ruby doesn't have the concept of non-member functions — all methods belong to a class. Therefore, `ruby-bindgen` automatically converts non-member operators to instance methods on the first argument's class:

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

```ruby
# Generated Ruby bindings
matrix1 = Matrix.new
matrix2 = Matrix.new

matrix1.assign_plus(matrix2)   # Calls operator+=(matrix1, matrix2)
matrix1.assign_multiply(2.0)   # Calls operator*=(matrix1, 2.0)
```

### Non-Member Unary Operators

Non-member unary operators (common in libraries like OpenCV) are wrapped via lambdas:

```cpp
MatExpr operator~(const Mat& m);   // Bitwise NOT
MatExpr operator-(const Mat& m);   // Negation
MatExpr operator+(const Mat& m);   // Unary plus
```

`ruby-bindgen` generates:

```cpp
rb_cMat.
    define_method("~", [](const Mat& self) -> MatExpr { return ~self; }).
    define_method("-@", [](const Mat& self) -> MatExpr { return -self; }).
    define_method("+@", [](const Mat& self) -> MatExpr { return +self; });
```

### Streaming Operators

The `<<` operator is commonly used for two different purposes in C++:

1. **Output streaming** (`std::ostream& operator<<(std::ostream&, const T&)`) — `ruby-bindgen` converts these to `inspect` methods on the streamed class.

2. **Other streaming** (e.g., `FileStorage& operator<<(FileStorage&, const T&)`) — `ruby-bindgen` converts these to `<<` instance methods.

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

C++ [conversion operators](https://en.cppreference.com/w/cpp/language/cast_operator) are mapped to Ruby `to_*` methods:

```cpp
operator double() const;         // to_f
operator bool() const;           // to_bool
operator std::string() const;    // to_s
```

### Conversion Type Mappings

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

Custom types are mapped to `to_<typename>` in snake_case (e.g., `operator MyClass()` becomes `to_my_class`). Pointer conversions map to `to_ptr` or `to_const_ptr`.
