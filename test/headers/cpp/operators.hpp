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
