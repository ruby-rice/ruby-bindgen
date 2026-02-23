# Architecture

`ruby-bindgen` uses [libclang](https://clang.llvm.org/doxygen/group__CINDEX.html), via [ffi-clang](https://github.com/ioquatix/ffi-clang), to parse C and C++ header files.

Libclang represents the [Abstract Syntax Tree (AST)](https://en.wikipedia.org/wiki/Abstract_syntax_tree) as a hierarchy of cursors. Each cursor is a node representing a declaration, statement, or expression. For example, parsing this header:

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

For C and C++ bindings, `ruby-bindgen` uses the [visitor pattern](https://en.wikipedia.org/wiki/Visitor_pattern) to walk this tree. Each cursor kind is dispatched to a corresponding `visit_*` method (e.g., `visit_class_decl`, `visit_cxx_method`), which generates binding code via ERB templates.

``` mermaid
flowchart TD
    subgraph Input
        H["C/C++ headers"]
        Y["bindings.yaml"]
    end

    subgraph Parsing
        FC["ffi-clang"]
        AST["AST"]
        FC --> AST
    end

    subgraph "Code Generation"
        V1["Visitor"]
        ERB1["ERB templates"]
        V1 --> ERB1
    end

    subgraph Output
        F["Rice/FFI files"]
    end

    H --> FC
    Y --> V1
    AST --> V1
    ERB1 --> F
```

For CMake bindings, `ruby-bindgen` runs as a second pass, scanning the output directory for previously generated `*-rb.cpp` files.

``` mermaid
flowchart TD
    subgraph Input
        Y["bindings.yaml"]
        S["*-rb.cpp"]
    end

    subgraph "Code Generation"
        V2["CMake visitor"]
        ERB2["ERB templates"]
        V2 --> ERB2
    end

    subgraph Output
        F["CMakeLists.txt / CMakePresets.json"]
    end

    Y --> V2
    S --> V2
    ERB2 --> F
```

## Source Layout

The [key classes](#key-classes) live under `lib/ruby-bindgen/`. Each output format (Rice, FFI, CMake) has its own directory under `visitors/` containing both the visitor implementation and its ERB templates.

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
    │   └── *.erb              # ERB templates
    ├── ffi/                   # C FFI binding generator
    │   ├── ffi.rb             # Visitor
    │   └── *.erb              # ERB templates
    └── cmake/                 # CMake build file generator
        ├── cmake.rb           # Visitor
        └── *.erb              # ERB templates
```

Most visitor methods delegate to ERB templates for code generation. Each template receives the current cursor and any visitor state as local variables, and outputs a string of generated code.

For example, the Rice visitor's `cxx_method.erb` template generates a `define_method` call:

```cpp
define_method<<%= method_signature(cursor) %>("<%= cursor.ruby_name %>", &<%= cursor.qualified_name %>,
  <%= arguments(cursor) %>).
```

## Key Classes

### Config

The `Config` class loads the YAML configuration file and resolves platform-specific settings. It detects whether to use `clang:` or `clang-cl:` based on `RUBY_PLATFORM`, resolves relative paths against the config file's directory, and provides hash-like access to all configuration values.

### Inputter

The `Inputter` class discovers header files to process. Given a base directory and glob patterns from the config (`match:` and `skip:`), it iterates over matching files and yields both absolute and relative paths.

### Parser

The `Parser` class wraps ffi-clang's `Index` and drives the processing loop:

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

The `Outputter` class writes generated files to the output directory. It tracks all written paths and applies whitespace cleanup (removing excessive blank lines and blank lines before closing braces) to keep the output tidy.

### Namer

The `Namer` class converts C++ names to Ruby conventions:

- `CamelCase` class names stay as-is (Ruby classes are CamelCase)
- `camelCase` and `PascalCase` method names become `snake_case`
- `isFoo()` / `hasFoo()` become `foo?`
- C++ operators map to Ruby operators (`operator+` → `+`, `operator==` → `==`)
- `operator[]` maps to both `[]` and `[]=` (if the return type is a reference)
- `operator()` maps to `call`
- Conversion operators like `operator int()` map to `to_i`, `operator string()` to `to_s`
- C variable names for Rice classes use the `rb_c` prefix (e.g., `rb_cCvMat`)

## Refinements to ffi-clang

`ruby-bindgen` extends ffi-clang's classes using Ruby refinements in `lib/ruby-bindgen/refinements/`:

- **Cursor** - adds `ruby_name`, `cruby_name`, `qualified_name`, `class_name_cpp`, and methods for finding children by kind
- **Type** - adds `fully_qualified_spelling` for reconstructing C++ type names with proper namespace qualification and template arguments
- **TranslationUnit** - adds `includes` to extract `#include` directives
- **String** - adds `camelize` and `underscore` for name conversion
- **SourceRange** - adds `text` for extracting source text from a range

## Rice Visitor Details

The Rice visitor is the most complex (~2100 lines) because C++ has the most features to handle. Some notable aspects:

### Traversal

The visitor traverses the AST recursively. Each cursor kind is dispatched to a `visit_*` method (e.g., `visit_class_decl`, `visit_cxx_method`) which checks whether the cursor should be skipped and, if not, renders an ERB template to generate the binding code.

### Filtering

Before generating code for a cursor, the visitor applies several filters. See [filtering](cpp/filtering.md) for details.

### Template Handling

C++ class templates require special treatment. See [templates](cpp/templates.md) for details.

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

