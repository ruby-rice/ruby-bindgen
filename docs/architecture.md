# Architecture

This page describes how `ruby-bindgen` is implemented.

## Processing Pipeline

``` mermaid
flowchart LR
    subgraph Input
        H["C/C++ headers"]
        Y["bindings.yaml"]
    end

    subgraph Parsing
        FC["ffi-clang"]
        AST["Cursor-based AST"]
        FC --> AST
    end

    subgraph "Code Generation (Rice/FFI)"
        V1["AST Visitor"]
        ERB1["ERB templates"]
        V1 --> ERB1
    end

    subgraph "Code Generation (CMake)"
        FS["Scan output dir for *-rb.cpp"]
        V2["CMake visitor"]
        ERB2["ERB templates"]
        FS --> V2
        V2 --> ERB2
    end

    subgraph Output
        F["Generated files"]
    end

    H --> FC
    Y --> V1
    AST --> V1
    Y --> V2
    ERB1 --> F
    ERB2 --> F
```

## Libclang and ffi-clang

`ruby-bindgen` uses [libclang](https://clang.llvm.org/doxygen/group__CINDEX.html), Clang's C API for parsing C and C++ source code. Libclang provides a stable, high-level interface to Clang's parser without requiring the full compiler. It parses headers and produces an abstract syntax tree (AST).

[ffi-clang](https://github.com/ioquatix/ffi-clang) is a Ruby gem that wraps libclang using Ruby FFI, making the C API accessible from Ruby. It exposes libclang's cursor-based traversal model directly.

### Cursor-Based AST

Libclang represents the AST as a hierarchy of **cursors**. Each cursor is a node in the tree representing a declaration, statement, or expression. A cursor has:

- **Kind** - what the node represents (`class_decl`, `cxx_method`, `enum_decl`, `function_decl`, etc.)
- **Spelling** - the name of the declaration
- **Type** - the C++ type associated with the cursor
- **Location** - source file and line number
- **Children** - nested cursors (methods inside classes, parameters inside functions, etc.)

For example, parsing this header:

```cpp
namespace cv {
  class Mat {
    Mat(int rows, int cols, int type);
    int rows;
    bool empty() const;
  };
}
```

Produces a cursor tree like:

```
namespace (cv)
  └── class_decl (Mat)
        ├── constructor (Mat)
        │     ├── parm_decl (rows)
        │     ├── parm_decl (cols)
        │     └── parm_decl (type)
        ├── field_decl (rows)
        └── cxx_method (empty)
```

`ruby-bindgen` walks this tree and generates binding code for each cursor.

## Key Classes

### Config

`Config` loads the YAML configuration file and resolves platform-specific settings. It detects whether to use `clang:` or `clang-cl:` based on `RUBY_PLATFORM`, resolves relative paths against the config file's directory, and provides hash-like access to all configuration values.

### Inputter

`Inputter` discovers header files to process. Given a base directory and glob patterns from the config (`match:` and `skip:`), it iterates over matching files and yields both absolute and relative paths.

### Parser

`Parser` wraps ffi-clang's `Index` and drives the processing loop:

```ruby
def generate(visitor)
  visitor.visit_start

  inputter.each do |path, relative_path|
    translation_unit = @index.parse_translation_unit(path, clang_args, [],
      [:detailed_preprocessing_record, :skip_function_bodies])
    visitor.visit_translation_unit(translation_unit, path, relative_path)
  end

  visitor.visit_end
end
```

For each header file, it calls `parse_translation_unit`, which returns a translation unit object. Visitors access the root cursor via `translation_unit.cursor`.

Parse options include `:skip_function_bodies` (we only need declarations, not implementations) and `:detailed_preprocessing_record` (to see preprocessor directives).

### Outputter

`Outputter` writes generated files to the output directory. It tracks all written paths and applies whitespace cleanup (removing excessive blank lines and blank lines before closing braces) to keep the output tidy.

## Visitor Pattern

The core of `ruby-bindgen` is the **visitor pattern**. Rice and FFI visitors traverse AST cursors and generate code per cursor kind. The CMake visitor is different: it generates files by scanning previously generated `*-rb.cpp` files in the output directory.

### How Cursors Map to Visitor Methods

When processing a cursor's children, the visitor calls `figure_method` to map cursor kinds to visitor method names:

| Cursor Kind | Visitor Method |
|------------|----------------|
| `:cursor_class_decl`, `:cursor_struct` | `visit_class_decl` |
| `:cursor_cxx_method` | `visit_cxx_method` |
| `:cursor_constructor` | `visit_constructor` |
| `:cursor_enum_decl` | `visit_enum_decl` |
| `:cursor_function` | `visit_function` |
| `:cursor_field_decl` | `visit_field_decl` |
| `:cursor_namespace` | `visit_namespace` |
| `:cursor_typedef_decl` | `visit_typedef_decl` |
| `:cursor_type_alias_decl` | `visit_type_alias_decl` |
| `:cursor_union` | `visit_union` |
| `:cursor_variable` | `visit_variable` |
| `:cursor_conversion_function` | `visit_conversion_function` |

Cursors that don't map to a visitor method (e.g., access specifiers, friend declarations) are skipped.

This mapping applies to AST-driven visitors (Rice/FFI). CMake generation does not use cursor-kind dispatch.

### Traversal

The visitor traverses the AST recursively. `visit_children` iterates over a cursor's children, calling the appropriate `visit_*` method for each one. `render_children` does the same but collects the generated code strings and joins them. `merge_children` concatenates all child output into a single string.

Each `visit_*` method typically:
1. Checks whether the cursor should be skipped (system header, skip list, deprecated, etc.)
2. Calls `render_template` to generate code from an ERB template
3. Returns the generated code string

### Filtering

Before generating code for a cursor, the visitor applies several filters:

- **Location** - skip cursors from system headers or files outside the input directory
- **Access** - skip private and protected members
- **skip_symbols** - user-configured list of names, qualified names, or regex patterns to skip
- **export_macros** - if configured, only include functions whose source contains the specified macros
- **Deprecated** - skip functions marked with `__attribute__((deprecated))`
- **Incomplete types** - skip methods returning pointers to forward-declared types

## ERB Templates

Most visitor methods delegate to ERB templates for code generation. Each template receives the current cursor and any visitor state as local variables, and outputs a string of generated code.

For example, the Rice visitor's `cxx_method.erb` template generates a `define_method` call:

```cpp
define_method<<%= method_signature(cursor) %>("<%= cursor.ruby_name %>", &<%= cursor.qualified_name %>,
  <%= arguments(cursor) %>).
```

### Template Organization

Each visitor has its own template directory:

**Rice** (`visitors/rice/*.erb`) - 30 templates generating C++ code:
- `translation_unit.cpp.erb` / `.hpp.erb` / `.ipp.erb` - per-file wrapper files
- `class.erb` - `Rice::Data_Type<>` class definitions
- `constructor.erb` - `.define_constructor()` calls
- `cxx_method.erb` - `.define_method()` calls
- `enum_decl.erb` - `define_enum()` calls
- `function.erb` - `define_module_function()` calls
- `field_decl.erb` - `.define_attr()` calls
- `class_template.erb` / `class_template_specialization.erb` - template handling
- `project.cpp.erb` / `.hpp.erb` - master project files
- Operator templates for `[]`, binary, unary, and inspect operators

**FFI** (`visitors/ffi/*.erb`) - 10 templates generating Ruby code:
- `translation_unit.erb` - Ruby module wrapper
- `function.erb` - `attach_function` calls
- `struct.erb` / `union.erb` - `FFI::Struct` / `FFI::Union` layout definitions
- `enum_decl.erb` - `enum` definitions
- `typedef_decl.erb` - type aliases
- `callback.erb` - `callback` definitions

**CMake** (`visitors/cmake/*.erb`) - 3 templates:
- `project.erb` - top-level `CMakeLists.txt`
- `directory.erb` - per-subdirectory `CMakeLists.txt`
- `presets.erb` - `CMakePresets.json`

### CMake Visitor Specifics

Unlike Rice and FFI, the CMake visitor's `visit_translation_unit` is intentionally empty. It generates output in `visit_start` by:

1. Scanning the output directory tree for `*-rb.cpp` files
2. Rendering top-level and per-directory `CMakeLists.txt`
3. Rendering `CMakePresets.json`

This is why CMake is typically run as a second pass after Rice generation.

## Refinements to ffi-clang

`ruby-bindgen` extends ffi-clang's classes using Ruby refinements in `lib/ruby-bindgen/refinements/`:

- **Cursor** - adds `ruby_name`, `cruby_name`, `qualified_name`, `class_name_cpp`, and methods for finding children by kind
- **Type** - adds `fully_qualified_spelling` for reconstructing C++ type names with proper namespace qualification and template arguments
- **TranslationUnit** - adds `includes` to extract `#include` directives
- **String** - adds `camelize` and `underscore` for name conversion
- **SourceRange** - adds `text` for extracting source text from a range

## Namer

The `Namer` class converts C++ names to Ruby conventions:

- `CamelCase` class names stay as-is (Ruby classes are CamelCase)
- `camelCase` and `PascalCase` method names become `snake_case`
- `isFoo()` / `hasFoo()` become `foo?`
- C++ operators map to Ruby operators (`operator+` → `+`, `operator==` → `==`)
- `operator[]` maps to both `[]` and `[]=` (if the return type is a reference)
- `operator()` maps to `call`
- Conversion operators like `operator int()` map to `to_i`, `operator string()` to `to_s`
- C variable names for Rice classes use the `rb_c` prefix (e.g., `rb_cCvMat`)

## Rice Visitor Details

The Rice visitor is the most complex (~2100 lines) because C++ has the most features to handle. Some notable aspects:

### Template Handling

C++ class templates require special treatment. When `ruby-bindgen` encounters a typedef or using declaration that instantiates a template:

```cpp
template<typename T> class Point_ { T x, y; };
typedef Point_<int> Point2i;
```

It generates an [`_instantiate` function](cpp/templates.md#template-instantiate-files-ipp) in a `.ipp` file that can instantiate the template for any type:

```cpp
template<typename T>
Rice::Data_Type<Point_<T>> Point__instantiate(Rice::Module parent, const char* name) {
  return Rice::define_class_under<Point_<T>>(parent, name).
    define_attr("x", &Point_<T>::x).
    define_attr("y", &Point_<T>::y);
}
```

And then calls it from the `.cpp` file:

```cpp
Rice::Data_Type<Point_<int>> rb_cPoint2i = Point__instantiate<int>(rb_mRoot, "Point2i");
```

This allows the same `_instantiate` function to be reused across translation units when a template is instantiated with different types in different files.

### Type Spelling

Reconstructing correct C++ type names from libclang's type information is one of the trickiest parts of the codebase. The `type_spelling` family of methods handles:

- Namespace qualification (`cv::Mat` not `Mat`)
- Template argument qualification (`std::vector<cv::Point>` not `std::vector<Point>`)
- Typedef resolution (knowing when to use the alias vs the underlying type)
- Dependent types in templates (adding `typename` where required)
- Elaborated types (`enum Foo` vs `Foo`)

### Default Arguments

Libclang provides limited information about default argument values. `ruby-bindgen` extracts default values from the source text and wraps them in `static_cast` with fully qualified types to ensure they compile in the generated context:

```cpp
// Original: void resize(int size, const Scalar& value = Scalar())
// Generated:
Arg("value") = static_cast<const cv::Scalar&>(cv::Scalar())
```

## Source Layout

```
lib/ruby-bindgen/
├── config.rb                  # YAML config loading
├── inputter.rb                # Header file discovery
├── outputter.rb               # File writing with cleanup
├── parser.rb                  # ffi-clang AST parsing
├── namer.rb                   # C++ → Ruby name conversion
├── version.rb
├── refinements/               # Extensions to ffi-clang classes
│   ├── cursor.rb
│   ├── type.rb
│   ├── translation_unit.rb
│   ├── string.rb
│   └── source_range.rb
└── visitors/
    ├── rice/                  # C++ Rice binding generator
    │   ├── rice.rb            # Visitor (~2100 lines)
    │   └── *.erb              # 29 ERB templates
    ├── ffi/                   # C FFI binding generator
    │   ├── ffi.rb             # Visitor
    │   └── *.erb              # 10 ERB templates
    └── cmake/                 # CMake build file generator
        ├── cmake.rb           # Visitor
        └── *.erb              # 3 ERB templates
```
