# Customizing

`ruby-bindgen` can customize the generated bindings in several ways:

- [`symbols: skip:`](../configuration.md#skip) — exclude specific functions, structs, enums, or typedefs by name or regex pattern
- [`symbols: overrides:`](../configuration.md#overrides-ffi-only) — replace the generated signature for specific functions when the heuristics pick the wrong FFI type
- [`export_macros`](../configuration.md#export-macros) — only include functions marked with specific visibility macros
- [`rename_types`](../configuration.md#name-mappings) — override generated Ruby module/class names
- [`rename_methods`](../configuration.md#name-mappings) — override generated Ruby method names

## Module Name

By default, the generated Ruby module is named after the header file (e.g., `proj.h` → `module Proj`). Use the [`module`](../configuration.md#c-ffi-options) option to override this, including nested modules:

```yaml
module: Proj::Api
```

This generates properly nested `module Proj` / `module Api` with correct indentation.
