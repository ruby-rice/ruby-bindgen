# Templates

`ruby-bindgen` generates bindings for C++ class templates, handling specializations, base class chains, and file organization automatically. For details on how Rice wraps class templates, see the Rice [Class Templates](https://ruby-rice.github.io/4.x/bindings/class_templates/) documentation.

## Template Classes and Specializations

`ruby-bindgen` generates bindings for template class instantiations created via `typedef` or `using` statements:

```cpp
template<typename T>
class Point
{
    T x, y;
};

typedef Point<int> Point2i;
using Point2f = Point<float>;
```

Generated bindings correctly handle:

- Fully qualified template arguments (`cv::Point<int>` not `Point<int>`)
- Base class inheritance chains for templates
- Auto-generation of base class bindings when no typedef exists

## Template Argument Qualification

Unqualified type names in template arguments are automatically qualified:

```cpp
// Input: std::map<String, DictValue>::iterator
// Output: std::map<cv::String, cv::dnn::DictValue>::iterator
```

## Template Base Classes

When a class inherits from a template instantiation, the base class binding is auto-generated if no typedef exists:

```cpp
class PlaneWarper : public WarperBase<PlaneProjector>
{
};
// Auto-generates WarperBasePlaneProjector binding
```

## Inheritance Chain Resolution

For template typedefs with base classes, the entire inheritance chain is resolved and generated in the correct order.

> **Warning:** Template class `_instantiate` functions do not currently include base class information due to a libclang crash when resolving base classes on certain templates. If your template class inherits from a base class, you will need to fix the generated `_instantiate` function by hand to add the base class parameter.

## Template Instantiate Files (.ipp)

When a header contains class templates with specializations (via `typedef` or `using`), `ruby-bindgen` generates reusable `_instantiate` template functions. These are placed in a separate `.ipp` file to enable reuse without duplicate symbol errors.

**Example**: For `templates.hpp` containing:

```cpp
template<typename T>
class Matrix
{
    ...
};

typedef Matrix<float> Matrixf;
```

`ruby-bindgen` generates:

**templates-rb.ipp** (template instantiate functions):
```cpp
#include <templates.hpp>
#include "templates-rb.hpp"

using namespace Rice;

template<typename T>
inline Rice::Data_Type<Matrix<T>> Matrix_instantiate(Rice::Module parent, const char* name)
{
  return Rice::define_class_under<Matrix<T>>(parent, name).
    define_constructor(Constructor<Matrix<T>>()).
    define_attr("data", &Matrix<T>::data);
}
```

**templates-rb.cpp** (Init function only):
```cpp
#include "templates-rb.ipp"

void Init_Templates()
{
  Rice::Data_Type<Matrix<float>> rb_cMatrixf =
    Matrix_instantiate<float>(Rice::Module(rb_cObject), "Matrixf");
}
```

### Reusing Instantiate Functions

The `.ipp` separation enables [refinement files](customizing.md) to reuse `_instantiate` functions without causing duplicate `Init_` symbol errors:

```cpp
// mat_refinements.cpp - Custom extensions
#include "mat-rb.ipp"  // Gets _instantiate functions, NOT Init_Core_Mat

void Init_Mat_Refinements()
{
  Rice::Data_Type<cv::Mat_<double>> rb_cMat1d =
    Mat__instantiate<double>(rb_mCv, "Mat1d");
}
```
