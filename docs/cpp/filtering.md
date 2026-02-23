# Filtering

`ruby-bindgen` provides several mechanisms to control which symbols are included in the generated bindings.

## Export Macros

See [`export_macros`](../configuration.md#export-macros) in the configuration documentation.

## Skip Symbols

See [`skip_symbols`](../configuration.md#skip-symbols) in the configuration documentation.

## Automatic Skipping

The following are automatically skipped:

- **Deprecated**: Functions with `__attribute__((deprecated))`
- **Internal**: Functions ending with underscore (`func_`)
- **Variadic**: Functions with `...` parameters
- **Deleted**: Methods marked `= delete`
- **Private/Protected**: Non-public members
- **Template functions**: Non-member function templates (e.g., `template<typename T> void func()`)
- **Anonymous namespaces**: Internal implementation details

## std:: Typedefs

Typedefs to `std::` types are skipped since Rice handles them automatically:

```cpp
typedef std::string String;  // Skipped - Rice handles std::string
```

