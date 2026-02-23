# Iterators

`ruby-bindgen` automatically generates Rice `define_iterator` calls for C++ classes that expose iterator methods. This provides Ruby's `Enumerable` module support for C++ containers. For details on how Rice bridges C++ iterators to Ruby, see the Rice [Iterators](https://ruby-rice.github.io/4.x/bindings/iterators/) documentation.

## Automatic Iterator Detection

When `ruby-bindgen` encounters a C++ class with `begin()` and `end()` methods that return iterators, it automatically generates the appropriate `define_iterator` calls. For example, a C++ class like:

```cpp
class Bitmap {
public:
    PixelIterator begin();
    PixelIterator end();
};
```

Will generate:

```cpp
define_class_under<Bitmap>(rb_mModule, "Bitmap").
    define_iterator<PixelIterator(Bitmap::*)()>(&Bitmap::begin, &Bitmap::end, "each");
```

**Note:** If a class only defines `begin() const` and `end() const` (without non-const versions), the generated method will be `each_const`. Since Ruby conventions expect `each`, `ruby-bindgen` automatically aliases `each` to `each_const` in this case.

## Multiple Iterator Types

`ruby-bindgen` handles classes with multiple iterator types, such as const iterators, reverse iterators, and const reverse iterators:

| Method Pair           | Ruby Method Name     |
|-----------------------|----------------------|
| `begin()`/`end()`     | `each`               |
| `begin() const`/`end() const` | `each_const` |
| `rbegin()`/`rend()`   | `each_reverse`       |
| `rbegin() const`/`rend() const` | `each_reverse_const` |

## Incomplete Iterator Traits

Some C++ libraries define iterators that lack the required `std::iterator_traits` typedefs. These iterators are missing one or more of:

- `value_type`
- `reference`
- `pointer`
- `difference_type`
- `iterator_category`

Rice's `define_iterator` requires these traits to function properly. Without them, you'll see compile errors like:

```
error C2039: 'value_type': is not a member of 'std::iterator_traits<MyIterator>'
```

### Automatic Traits Generation

`ruby-bindgen` automatically detects incomplete iterators and generates `std::iterator_traits` specializations for them. For example, given an iterator like:

```cpp
// Iterator WITHOUT proper std::iterator_traits
class IncompleteIterator
{
public:
    IncompleteIterator() : ptr_(nullptr) {}
    explicit IncompleteIterator(Pixel* p) : ptr_(p) {}
    Pixel& operator*() const { return *ptr_; }
    IncompleteIterator& operator++() { ++ptr_; return *this; }
    bool operator!=(const IncompleteIterator& other) const { return ptr_ != other.ptr_; }

private:
    Pixel* ptr_;
    // NOTE: Missing value_type, reference, pointer, difference_type, iterator_category
};
```

`ruby-bindgen` will generate:

```cpp
// Iterator traits specializations for iterators missing std::iterator_traits
namespace std
{
  template<>
  struct iterator_traits<iter::IncompleteIterator>
  {
    using iterator_category = forward_iterator_tag;
    using value_type = iter::Pixel;
    using difference_type = ptrdiff_t;
    using pointer = iter::Pixel*;
    using reference = iter::Pixel&;
  };
}
```

## Examples

See [test/headers/cpp/iterators.hpp](../test/headers/cpp/iterators.hpp) for example iterator classes, including both complete and incomplete iterators. The generated bindings are in [test/bindings/cpp/iterators-rb.cpp](../test/bindings/cpp/iterators-rb.cpp).
