# Constants and Macros

`ruby-bindgen` generates Ruby constants from top-level `const` variables with literal initializers:

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

Macros are not added to bindings because their values are baked in at generation time and thus not read at runtime. This easily causes confusion. For example, a version macro like `PROJ_VERSION_MAJOR` would reflect whichever library version was used to generate bindings, not the version actually being used on your machine.
