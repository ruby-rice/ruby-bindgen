# Type Mapping

## String and Pointer Types

C uses `char *` for both strings and raw memory buffers. `ruby-bindgen` uses const-qualification and context to choose the correct FFI type:

| Context | `const char *` | `char *` |
|---------|---------------|----------|
| Function parameters | `:string` | `:pointer` |
| Function returns | `:string` | `:pointer` |
| Callback returns | `:pointer` | `:pointer` |
| Struct/union fields | `:string` | `:pointer` |

**Rationale:**

- **`const char *`** is a read-only string — FFI auto-converts to a Ruby `String`.
- **`char *`** typically indicates a caller-allocated buffer (e.g., `char *buf, size_t buf_size`), so `:pointer` is correct — the caller creates the buffer with `FFI::MemoryPointer.new`.
- **Callback returns** always use `:pointer` regardless of const because FFI cannot manage the lifetime of callback-returned strings.

If a specific function needs a different type mapping, use [`symbols: overrides:`](../configuration.md#overrides-ffi-only) to replace the generated signature.

## Struct Pointer Types

When a function parameter is a pointer to a struct, `ruby-bindgen` generates `StructName.by_ref`. This is correct for the common case of passing a single struct by pointer:

```c
int proj_get_area_of_use(PJ *obj, double *west, ...);
// → attach_function :proj_get_area_of_use, ..., [:pointer, :pointer, ...], :int
```

However, `.by_ref` is **wrong** when the pointer is actually an array of structs. `ruby-bindgen` cannot distinguish these cases from the C signature alone — both are just `SomeStruct *`. Two common patterns:

**Array parameters** — a count parameter precedes the struct pointer:

```c
PJ *proj_create_conversion(PJ_CONTEXT *ctx, ..., int param_count,
                            const PJ_PARAM_DESCRIPTION *params);
```

Here `params` points to an array of `param_count` structs. The caller allocates the array with `FFI::MemoryPointer` and writes structs into it.

**Array returns** — a function returns a pointer to a statically-allocated or heap-allocated array of structs:

```c
const PJ_OPERATIONS *proj_list_operations(void);
```

This returns a NULL-terminated array of `PJ_OPERATIONS` structs, not a single struct. The caller iterates the array by advancing the pointer.

Use [`symbols: overrides:`](../configuration.md#overrides-ffi-only) to fix these:

```yaml
symbols:
  overrides:
    proj_create_conversion: "[:pointer, :string, :string, :string, :string, :string, :string, :int, :pointer], :pointer"
    proj_list_operations: "[], :pointer"
```
