# Type Spelling in `ruby-bindgen`

This document explains why generating correct, fully-qualified C++ type spellings from libclang is inherently complex, and how `ruby-bindgen` addresses that complexity.

## TL;DR

- There is no single libclang API that always returns the right C++ spelling for code generation.
- Canonical types are often semantically correct but syntactically wrong for generated bindings.
- `ruby-bindgen` reconstructs type spellings based on cursor kind and context, with canonicalization only as a fallback.

The objective is **not** to compute a canonical or normalized type. The objective is to emit a C++ spelling that:

1. Compiles correctly at the binding site
2. Preserves user-facing API intent (typedefs, aliases, dependent names)
3. Is stable across compilers and standard library implementations

## The Problem

When generating Rice bindings, `ruby-bindgen` must emit fully-qualified C++ type names that are valid in generated code.

For example:

```cpp
// Required
Constructor<cv::Mat, const cv::Range&, const cv::Range&>

// Incorrect (missing namespace qualification)
Constructor<Mat, const Range&, const Range&>
```

libclang exposes multiple APIs for retrieving type information, but **none provide a complete, correct spelling for all C++ constructs**.

This is a fundamental consequence of C++’s type system and libclang’s design goals.

## Why a Canonical-Based Approach Fails

An initial strategy was to rely on `type.canonical.spelling` and then filter out implementation details. This approach fails in several unavoidable cases.

### Failure Modes

| Feature | Result from `canonical.spelling` | Why this is incorrect |
|-------|----------------------------------|------------------------|
| **Typedefs / aliases** | `SizeArray` → `int[3]` | Destroys alias intent and public API spelling |
| **Templates** | `iterator` → `std::iterator` | Loses specialization and template context |
| **Dependent types** | Missing `typename`, incorrect qualification | Canonical types erase dependency information |
| **Namespaces** | Over- or under-qualified names | Ignores lexical context |

In addition, canonical spellings frequently expose **implementation details** that must never appear in generated bindings:

- `__gnu_cxx::__normal_iterator<...>` (libstdc++)
- `_Ty`, `_Alloc`, `_Vector_iterator` (MSVC STL)

Filtering these reliably is not possible without reconstructing the original spelling logic, which defeats the purpose of canonicalization.

### Key Insight

`canonical.spelling` answers:

> “What is this type semantically?”

`ruby-bindgen` must answer:

> “How must this type be written so that user code compiles correctly and reflects the original API?”

These questions are fundamentally different.

## What libclang Provides

libclang exposes several partial representations of a type, each optimized for a different purpose:

| API | Returns | Limitation |
|----|---------|------------|
| `type.spelling` | Source-level spelling | Often unqualified |
| `type.canonical.spelling` | Fully desugared type | Erases typedefs and context |
| `declaration.qualified_name` | Namespace-qualified name | Drops template arguments |
| `declaration.qualified_display_name` | Name + template parameters | May omit enclosing namespaces |

No single API preserves both **spelling fidelity** and **correct qualification**.

## `ruby-bindgen`’s Strategy

`ruby-bindgen` does not attempt to normalize all types through a single representation.

Instead, `type_spelling` reconstructs the correct spelling **based on cursor kind and context**, using canonical information only as a constrained fallback.

### Design Principle

> **Spelling fidelity is primary; canonicalization is secondary and opportunistic.**

### Cursor-Specific Handling

#### `cursor_class_template`

Template definitions (e.g., `template<typename T> class Vec`).

- Reconstruct template arguments explicitly
- Use `qualify_dependent_types_in_template_args`
- Do not consult `@type_name_map` (template parameters must remain dependent)

#### `cursor_typedef_decl` inside a class template

Dependent typedefs (e.g., `DataType<_Tp>::value_type`).

- Emit `typename` (required by the C++ standard)
- Combine `qualified_name` with `qualified_display_name`
- Preserve dependency instead of resolving it

#### `cursor_typedef_decl` (non-dependent)

Public typedefs (e.g., `typedef Point_<int> Point2i`).

- Preserve the typedef name
- Do not desugar to the underlying type
- Qualify template arguments via `@type_name_map`

#### `cursor_type_alias_decl`

C++11 `using` declarations.

- Treated identically to `cursor_typedef_decl`
- Required for cross-compiler support (MSVC favors `using`)

#### `cursor_class_decl` and related types

Concrete types and template instantiations.

- Start from `fully_qualified_spelling`
- Optionally consult `canonical.spelling`
    - Only when it does not introduce implementation types
- Qualify template arguments using `qualify_template_args`

## The `@type_name_map`

During translation unit processing, `ruby-bindgen` builds a map from simple identifiers to fully-qualified names:

```ruby
{
  "Range" => "cv::Range",
  "Mat"   => "cv::Mat",
  "Pixel" => "iter::Pixel"
}
```

This map is used to qualify **unqualified template arguments**, not to rewrite dependent names or template parameters.

## Where Canonicalization Works

`canonical.spelling` is useful only in limited cases:

- Non-dependent `cursor_class_decl` types
- Situations where alias preservation is irrelevant
- As a fallback sanity check for namespace qualification

It is not the primary source of truth.

## Why Not Use Clang’s C++ API?

Clang’s C++ API (`libTooling`) provides:

- `PrintingPolicy`
- Direct AST printers for fully-qualified names
- Precise control over dependent type emission

However:

- `ruby-bindgen` uses `ffi-clang`, which exposes only libclang’s C API
- libclang is designed for IDEs and static analysis tools, not code generation
- Reimplementing spelling logic is unavoidable in this environment

`ruby-bindgen`’s type spelling logic exists specifically to bridge this gap.

## Summary

There is no single libclang call that can produce correct C++ type spellings in all cases.

The complexity in `ruby-bindgen` is inherent:

- C++ has typedefs, aliases, templates, dependent types, and contextual name lookup
- libclang exposes these differently depending on cursor kind
- Correct code generation requires spelling reconstruction, not canonicalization

The current design reflects these constraints deliberately.

## Code Locations

- Core logic:  
  `lib/ruby-bindgen/visitors/rice/rice.rb`  
  (`type_spelling`, `type_spelling_elaborated`)

- Qualified name helpers:  
  `lib/ruby-bindgen/refinements/type.rb`  
  (`fully_qualified_spelling`)

- Template argument qualification:  
  `qualify_template_args`  
  `qualify_dependent_types_in_template_args`
