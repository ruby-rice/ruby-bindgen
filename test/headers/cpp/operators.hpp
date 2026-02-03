// Test header for C++ operators
// Based on Rice documentation for operator mappings

class Operators
{
public:
    int value;

    Operators();
    Operators(int v);

    // Arithmetic operators - map directly to Ruby
    Operators operator+(const Operators& other) const;
    Operators operator-(const Operators& other) const;
    Operators operator*(const Operators& other) const;
    Operators operator/(const Operators& other) const;
    Operators operator%(const Operators& other) const;

    // Assignment operators - map to Ruby methods
    Operators& operator=(const Operators& other);
    Operators& operator+=(const Operators& other);
    Operators& operator-=(const Operators& other);
    Operators& operator*=(const Operators& other);
    Operators& operator/=(const Operators& other);
    Operators& operator%=(const Operators& other);

    // Bitwise operators - map directly to Ruby
    Operators operator&(const Operators& other) const;
    Operators operator|(const Operators& other) const;
    Operators operator^(const Operators& other) const;
    Operators operator~() const;
    Operators operator<<(int shift) const;
    Operators operator>>(int shift) const;

    // Bitwise assignment operators - map to Ruby methods
    Operators& operator&=(const Operators& other);
    Operators& operator|=(const Operators& other);
    Operators& operator^=(const Operators& other);
    Operators& operator<<=(int shift);
    Operators& operator>>=(int shift);

    // Comparison operators - map directly to Ruby
    bool operator==(const Operators& other) const;
    bool operator!=(const Operators& other) const;
    bool operator<(const Operators& other) const;
    bool operator>(const Operators& other) const;
    bool operator<=(const Operators& other) const;
    bool operator>=(const Operators& other) const;

    // Logical operators
    bool operator!() const;
    bool operator&&(const Operators& other) const;
    bool operator||(const Operators& other) const;

    // Increment/Decrement operators - map to Ruby methods
    Operators& operator++();      // prefix ++a -> increment_pre
    Operators operator++(int);    // postfix a++ -> increment
    Operators& operator--();      // prefix --a -> decrement_pre
    Operators operator--(int);    // postfix a-- -> decrement

    // Subscript operator - maps to [] and []=
    int& operator[](int index);
    const int& operator[](int index) const;

    // Function call operator - maps to call
    int operator()(int a, int b);

    // Dereference operator - maps to dereference
    int operator*() const;

    // Arrow operator - maps to arrow
    Operators* operator->();
    const Operators* operator->() const;

    // Conversion operators - map to to_* methods
    operator int() const;
    operator float() const;
    operator bool() const;

private:
    int data[10];
};

// Test conversion to namespaced types
namespace conv
{
    class Target
    {
    public:
        int value;
        Target() : value(0) {}
        Target(int v) : value(v) {}
    };
}

class NamespacedConversion
{
public:
    int value;
    NamespacedConversion() : value(0) {}
    NamespacedConversion(int v) : value(v) {}

    // Conversion to namespaced type - should generate to_target method (not to_conv/target)
    operator conv::Target() const { return conv::Target(value); }

    // Conversion to reference - should generate to_target method (not to_conv/target &)
    operator conv::Target&();
};

// Template class with pointer conversion operators
// Tests that operator T*() maps to to_ptr and operator const T*() const maps to to_const_ptr
template <typename T>
class DataPtr
{
public:
    T* data;

    DataPtr() : data(nullptr) {}
    DataPtr(T* ptr) : data(ptr) {}

    // Conversion to pointer - should generate to_ptr method
    operator T*() { return data; }

    // Conversion to const pointer - should generate to_const_ptr method  
    operator const T*() const { return data; }
};

typedef DataPtr<int> DataPtrInt;
typedef DataPtr<float> DataPtrFloat;

// Test non-member operators - these are wrapped in lambdas
// The lambda body should use the C++ operator (+=), not the Ruby name (assign_plus)
class Matrix
{
public:
    int rows, cols;
    Matrix() : rows(0), cols(0) {}
    Matrix(int r, int c) : rows(r), cols(c) {}
};

// Non-member compound assignment operator
// Should generate: return self += other; (NOT: return self assign_plus other;)
Matrix& operator+=(Matrix& a, const Matrix& b);
Matrix& operator-=(Matrix& a, const Matrix& b);
Matrix& operator*=(Matrix& a, double scalar);

// Non-member unary operators (like OpenCV's operator~(const Mat& m))
// These have only 1 argument and should generate the correct Ruby method name:
//   ~ -> "~"
//   - -> "-@" (Ruby's unary minus)
//   + -> "+@" (Ruby's unary plus)
Matrix operator~(const Matrix& m);
Matrix operator-(const Matrix& m);
Matrix operator+(const Matrix& m);

// Test non-member << operators
#include <ostream>
#include <string>

// Class that can be printed to ostream (should generate inspect method)
class Printable
{
public:
    std::string name;
    int value;

    Printable() : name("default"), value(0) {}
    Printable(const std::string& n, int v) : name(n), value(v) {}
};

// ostream << operator - should generate inspect method
std::ostream& operator<<(std::ostream& os, const Printable& p);

// Class that acts like FileStorage (non-ostream streaming)
class FileWriter
{
public:
    FileWriter() {}

    // Methods to test the class works
    bool isOpen() const { return true; }
};

// Non-ostream << operator - should generate regular << method
FileWriter& operator<<(FileWriter& fw, const std::string& value);
FileWriter& operator<<(FileWriter& fw, int value);
FileWriter& operator<<(FileWriter& fw, const Printable& p);

// Test all conversion operator mappings
// Each C++ type maps to a specific Ruby method name
class AllConversions
{
public:
    AllConversions() {}

    // Integer types
    operator int() const { return 1; }                        // to_i
    operator long() const { return 2L; }                      // to_i
    operator long long() const { return 3LL; }                // to_i64
    operator short() const { return 4; }                      // to_i16

    // Unsigned integer types
    operator unsigned int() const { return 5U; }              // to_u
    operator unsigned long() const { return 6UL; }            // to_ul
    operator unsigned long long() const { return 7ULL; }      // to_u64
    operator unsigned short() const { return 8; }             // to_u16


    // Floating point types
    operator float() const { return 9.0f; }                   // to_f32
    operator double() const { return 10.0; }                  // to_f
    operator long double() const { return 11.0L; }            // to_f

    // Other types
    operator bool() const { return true; }                    // to_bool
    operator std::string() const { return "hello"; }          // to_s
};

// Test size_t conversion separately to see what clang reports
class SizeTConversion
{
public:
    size_t value;
    SizeTConversion() : value(0) {}
    operator size_t() const { return value; }
};

// =============================================================================
// Test that non-member operators for std:: types that Rice converts to
// native Ruby types are SKIPPED (no Rice wrapper exists for these).
// =============================================================================

// Typedef to std::string (like cv::String)
typedef std::string MyString;

// This operator should be SKIPPED because MyString is std::string,
// which Rice converts to Ruby String (no Rice wrapper class exists).
// If not skipped, generated code would try to add methods to rb_cString
// which is Ruby's built-in String class.
MyString& operator<<(MyString& out, const Printable& p);
