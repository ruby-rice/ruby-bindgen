# Enums

`ruby-bindgen` generates Rice enum bindings for both scoped and unscoped C++ enums. For details on the generated Ruby enum API (comparison, conversion, bitwise operations), see the Rice [Enums](https://ruby-rice.github.io/4.x/bindings/enums/) documentation.

## Scoped Enums (enum class)

```cpp
enum class Color { Red, Green, Blue };
```

Generates a Rice enum with properly scoped values.

## Unscoped Enums

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
