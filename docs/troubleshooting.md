# Troubleshooting

Common failures and how to fix them. Section headings match the exact
error string `ruby-bindgen` prints, so you can search for the message
verbatim.

## Pipeline and Failure Points

```mermaid
flowchart LR
  A["config.yaml"] --> B["ruby-bindgen"]
  B --> C["libclang parse"]
  C --> D["generated bindings"]
  D --> E["compile/link (Rice/CMake)"]
  D --> F["runtime load (FFI)"]

  X1["Fail: bad path / missing dirs"] -.-> A
  X2["Fail: libclang not found"] -.-> C
  X3["Fail: missing include args"] -.-> C
  X4["Fail: empty output due to filters"] -.-> D
  X5["Fail: linker missing symbols"] -.-> E
  X6["Fail: shared library not found"] -.-> F
```

For the full backtrace on any of these errors, set `BINDGEN_DEBUG=1`.

## `Error: Config file not found: <path>`

Cause:
- Wrong path passed to `ruby-bindgen`

Fix:
```bash
ruby-bindgen /absolute/path/to/config.yaml
```

## `Error: Config must specify 'output'`

Cause:
- The YAML file is missing the required top-level `output:` key.

Fix:
- Add `output: /path/to/output/dir` (the directory generated bindings are written to).

## `Error: Config must specify 'format'`

Cause:
- The YAML file is missing the required top-level `format:` key.

Fix:
- Add `format: Rice` (C++ via Rice), `format: FFI` (C via FFI), or `format: CMake` (CMake build files).

## `Error: Format must be 'FFI', 'Rice', or 'CMake', got: <value>`

Cause:
- `format:` is set to something other than the three accepted values. Match is case-sensitive.

Fix:
- Use exactly `Rice`, `FFI`, or `CMake`.

## `Error: Input path must be a directory: <path>`

Cause:
- `input:` points to a missing path or file (not a directory).

Fix:
- Set `input:` to an existing directory containing headers. For `format: CMake`, `input:` defaults to `output:` (the directory containing the generated `*-rb.cpp` files).

## `Error: Output path must be a directory: <path>`

Cause:
- `output:` directory does not exist.

Fix:
```bash
mkdir -p /path/to/output
ruby-bindgen config.yaml
```

## `Error: Project name must be a valid C/C++ identifier (hyphens allowed): <name>`

Cause:
- `project:` contains characters other than letters, digits, underscore, or hyphen, or starts with a digit.

Fix:
- Use a name like `my_extension` or `my-extension`. Hyphens are normalized to underscores in generated C++ identifiers.

## `Error: Rice include header not found: <path>`

Cause:
- `include:` (under a Rice config) names a header that does not exist under `output:`.

Fix:
- Confirm the file path is relative to `output:` and that the header is present before running. Without it, every generated `*-rb.hpp` would `#include` a missing file and the C++ build would fail far from the cause.

## `Error: libclang library not found: <path>`

Cause:
- `clang.libclang:` (or `clang-cl.libclang:`) explicitly points to a missing shared library.

Fix:
- Either correct the path or remove the `libclang:` key and rely on `ffi-clang`'s default discovery.

## `Error: clang args must be a YAML list, got: String`

Cause:
- `clang.args:` (or `clang-cl.args:`) is written as a single string instead of a YAML sequence.

Fix:
```yaml
clang:
  args:
    - -I/usr/include
    - -std=c++17
    - -xc++
```

## `libclang` runtime load failures

Symptoms:
- FFI load error for libclang
- Parser startup fails before processing files

Fix:
- Set the toolchain `libclang` path in config (`clang:` or `clang-cl:`)
- Verify the shared library exists and matches your architecture

Example:

```yaml
clang:
  libclang: /usr/lib/llvm-17/lib/libclang.so
  args:
    - -I/usr/lib/clang/17/include
    - -xc++
```

## Parse errors for standard/library types

Symptoms:
- Many unknown-type diagnostics
- Generated files missing expected classes/functions

Cause:
- Missing include paths or language flags in `clang.args`

Fix:
- Add system and project include paths
- Add `-xc++` for C++ headers (or `-xc` for C)
- Add `-std=c++17` (or your required standard)

## Empty or incomplete generated output

Cause:
- `match` glob too narrow
- `skip` glob too broad
- `export_macros` filters out everything

Fix:
- Validate `match`/`skip` patterns
- Temporarily remove `export_macros` and re-run to confirm filtering

## C++ compile failures after generation

Common causes:
- Missing includes in generated files
- Default argument edge cases
- Symbols declared in headers but not exported by the library

Fix:
- Use `symbols.skip` for problematic APIs, including overload-specific signatures when needed
- Add refinement files for custom behavior
- See [Updating Bindings](updating_bindings.md) for durable maintenance workflows

## CMake generation produced empty `target_sources`

Cause:
- No `*-rb.cpp` files in `output` yet

Fix:
- Run `format: Rice` generation first
- Then run `format: CMake`

## FFI runtime cannot load shared library

Cause:
- `library_names` / `library_versions` do not match installed artifacts

Fix:
- Set `library_names` to base names
- Add likely version suffixes to `library_versions`
- If the library is outside the standard loader path, use `library_search_path` and set the corresponding environment variable at runtime
- Confirm installation path is on loader search path

## Windows-specific

ruby-bindgen runs on Windows under both MSVC (mswin Ruby builds) and MinGW.
The toolchain is auto-detected via `RUBY_PLATFORM` — `mswin` uses the
`clang-cl:` config block, everything else uses `clang:`.

### Choosing MSVC vs MinGW

- **MSVC (`mswin`)** — recommended if you need to link against vcpkg or
  other MSVC-built dependencies. Uses `clang-cl` (Clang's MSVC-compatible
  driver) for header parsing.
- **MinGW** — uses regular `clang` and works with Unix-style include paths.
  Easier setup if the library is already buildable with MinGW.

### libclang load failure on Windows

Symptoms:
- `Error: libclang library not found: ...`
- FFI load error at startup

Fix:
- Visual Studio bundles libclang at
  `C:\Program Files\Microsoft Visual Studio\<edition>\<year>\VC\Tools\Llvm\x64\bin\libclang.dll`.
  Either install the "Clang/LLVM tools" component in the VS installer or
  install LLVM standalone and set `clang-cl.libclang:` to its `libclang.dll`.
- For MinGW Ruby, install LLVM via `pacman -S mingw-w64-clang-x86_64-clang`
  (or the appropriate variant) and set `clang.libclang:` to the resulting
  `libclang.dll`.

### Path separators

Use forward slashes (`/`) in YAML config paths even on Windows. The
inputter normalizes backslashes internally, but forward slashes avoid
YAML escape issues.

### vcpkg integration (MSVC)

If your library is installed via vcpkg, point `clang-cl.args:` at the
vcpkg include directory and `library_search_path:` at the bin directory:

```yaml
clang-cl:
  libclang: C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/Llvm/x64/bin/libclang.dll
  args:
    - -IC:/vcpkg/installed/x64-windows/include
    - -std:c++17

library_search_path: PATH
```
