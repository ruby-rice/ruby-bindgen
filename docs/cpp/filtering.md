# Filtering

`ruby-bindgen` provides several mechanisms to control which symbols are included in the generated bindings.

## Export Macros

Many libraries use macros to control which functions are exported. `ruby-bindgen` can honor these macros so that only exported functions are included in the generated bindings. See [`export_macros`](../configuration.md#export-macros) for details.

## Skipping Symbols

Sometimes you need to exclude specific symbols from the generated bindings — for example, internal APIs, symbols that cause linker errors, or platform-specific functions. `ruby-bindgen` supports skipping by name, qualified name, or regex pattern. See [`symbols.skip`](../configuration.md#skip) for details.

## Version Guards

When a library evolves across versions, some symbols are only available in newer releases. `ruby-bindgen` can wrap these symbols in version guards so the same bindings compile against multiple library versions. See [`symbols.versions`](../configuration.md#versions) for details.

## Automatic Skipping

The following are automatically skipped:

- **Deprecated**: Functions marked with `__attribute__((deprecated))` or `[[deprecated]]`
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

