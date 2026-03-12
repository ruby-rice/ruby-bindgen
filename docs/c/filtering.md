# Filtering

`ruby-bindgen` provides several mechanisms to control which symbols are included in the generated bindings.

## Export Macros

See [`export_macros`](../configuration.md#export-macros) in the configuration documentation.

## Symbols

See [`symbols`](../configuration.md#symbols) in the configuration documentation.

## Automatic Skipping

The following are automatically skipped:

- **Deprecated**: Functions marked with `__attribute__((deprecated))` or `[[deprecated]]`
- **Variadic**: Functions with `...` parameters (cannot be called via FFI)
- **Private/Protected**: Non-public members
- **System headers**: Declarations from system include paths
