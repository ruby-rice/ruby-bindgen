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
