# Constants and Macros

`ruby-bindgen` generates Ruby constants from two sources: `const` variables and `#define` macros.

## Const Variables

Top-level `const` variables with literal initializers are emitted as Ruby constants:

```c
const int CONST_INT = 10;
static const int STATIC_CONST_INT = 20;
const double CONST_DOUBLE = 3.14;
```

Generates:

```ruby
CONST_INT = 10
STATIC_CONST_INT = 20
CONST_DOUBLE = 3.14
```

## Macros

Simple `#define` macros that expand to a single literal value are emitted as Ruby constants:

```c
#define PROJ_VERSION_MAJOR 9
#define PROJ_VERSION_MINOR 3
#define PROJ_VERSION_PATCH 1
```

Generates:

```ruby
PROJ_VERSION_MAJOR = 9
PROJ_VERSION_MINOR = 3
PROJ_VERSION_PATCH = 1
```

> **Warning:** Only macros with a single literal token are supported. Macros that contain expressions, reference other macros, or take parameters are silently skipped. For example, the [PROJ](https://proj.org/) library defines:
>
> ```c
> #define PROJ_COMPUTE_VERSION(maj, min, patch) \
>     ((maj) * 10000 + (min) * 100 + (patch))
>
> #define PROJ_VERSION_NUMBER \
>     PROJ_COMPUTE_VERSION(PROJ_VERSION_MAJOR, PROJ_VERSION_MINOR, \
>                          PROJ_VERSION_PATCH)
> ```
>
> Neither `PROJ_COMPUTE_VERSION` (function-like macro) nor `PROJ_VERSION_NUMBER` (expression macro) will appear in the generated bindings. Only `PROJ_VERSION_MAJOR`, `PROJ_VERSION_MINOR`, and `PROJ_VERSION_PATCH` are generated because they each expand to a single integer literal.
>
> This is a limitation of libclang's macro representation — macro bodies are stored as raw preprocessor tokens rather than parsed expressions, so there is no way to evaluate them at generation time.
