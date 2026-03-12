# Version Guards

Some libraries ship symbols that only exist in certain versions. For example, OpenCV 4.5 added CUDA codec APIs that don't exist in 4.1. Version guards let you generate bindings that work across multiple library versions by wrapping version-specific symbols in conditional checks.

The mechanism differs by format:

- **Rice (C++)** — `#if` / `#endif` preprocessor directives checked at compile time
- **FFI (C)** — Ruby `if` conditionals checked at runtime via a user-implemented version method

## Rice (C++)

### Configuration

Two config options work together:

1. **`version_check`** — the C preprocessor macro to test (e.g., `CV_VERSION`)
2. **`symbols.versions`** — which symbols to guard and at what version

```yaml
format: Rice
version_check: CV_VERSION
symbols:
  versions:
    40100:
      - cv::Foo::newMethod
    40500:
      - /cv::cuda::.*/
```

Symbol names support the same syntax as skip symbols: simple names, fully qualified names, signatures, and regex patterns. See [Symbols](configuration.md#symbols) for details.

### Generated Output

#### Class methods

Version-guarded methods within a class produce inline `#if` / `#endif` around the chained method definition:

```cpp
Rice::Data_Type<cv::Foo> rb_cFoo = define_class<cv::Foo>("Foo")
  .define_method("bar", &cv::Foo::bar)
#if CV_VERSION >= 40100
  .define_method("new_method", &cv::Foo::newMethod)
#endif
  ;
```

#### Top-level functions

Version-guarded free functions are wrapped at the statement level:

```cpp
#if CV_VERSION >= 40100
define_global_function("new_func", &cv::newFunc);
#endif
```

### How It Works

When `version_check` is set, the generator looks up each symbol's version via the `symbols` config. Symbols with a version are grouped by their version value. The code generator emits `#if VERSION_MACRO >= version` before the group and `#endif` after it. Unversioned symbols are emitted normally with no guards.

## FFI (C)

For C libraries, version detection happens at runtime. When `symbols.versions` has entries, the generator:

1. Wraps version-specific symbols in `if {project}_version >= version` conditionals
2. Adds `require_relative '{project}_version'` to the project loader file
3. Generates a `{project}_version.rb` skeleton (once — won't overwrite if it already exists)

The user implements the version method by calling the library's own version API. See [Version Detection](c/version_guards.md) for a complete example using PROJ.
