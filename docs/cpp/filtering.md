# Filtering

`ruby-bindgen` provides several mechanisms to control which symbols are included in the generated bindings.

## Export Macros

The `export_macros` option filters functions based on the presence of specific macros in the source code. This is particularly useful for libraries like OpenCV that use macros to control symbol visibility.

When specified, only functions whose source text contains at least one of the listed macros will be included in the bindings. This prevents linker errors from trying to wrap internal functions that aren't exported from the shared library.

```yaml
export_macros:
  - CV_EXPORTS
  - CV_EXPORTS_W
```

### Common Library Macros

| Library | Export Macros |
|---------|--------------|
| OpenCV | `CV_EXPORTS`, `CV_EXPORTS_W`, `CV_EXPORTS_W_SIMPLE` |
| Qt | `Q_DECL_EXPORT`, `Q_CORE_EXPORT` |
| Boost | `BOOST_*_DECL` |

## Skip Symbols

Skip specific symbols by name, qualified name, or regex:

```yaml
skip_symbols:
  - internalFunc                    # Simple name
  - cv::internal::helper            # Qualified name
  - /cv::dnn::.*Layer::init.*/      # Regex pattern
```

## Automatic Skipping

The following are automatically skipped:

- **Deprecated**: Functions with `__attribute__((deprecated))`
- **Internal**: Functions ending with underscore (`func_`)
- **Variadic**: Functions with `...` parameters
- **Deleted**: Methods marked `= delete`
- **Private/Protected**: Non-public members
- **Anonymous namespaces**: Internal implementation details

## Incomplete Types (Pimpl Pattern)

Methods returning pointers or references to forward-declared types are automatically skipped:

```cpp
class MyClass {
    class Impl;  // Forward declaration
    Impl* getImpl();      // Skipped - returns pointer to incomplete type
    Impl& getImplRef();   // Skipped - returns reference to incomplete type
};
```

## std:: Typedefs

Typedefs to `std::` types are skipped since Rice handles them automatically:

```cpp
typedef std::string String;  // Skipped - Rice handles std::string
```

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
