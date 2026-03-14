# Library Loading

FFI loads the target shared library at runtime. The `library_names`, `library_versions`, and `library_search_path` configuration options specify where to find the library.

## Library Names

`library_names` specifies the base names of the shared library. The loader turns each base name into one or more search names and passes them to `ffi_lib`:

| Platform | `library_names: ["proj"]` searches for              |
|----------|-----------------------------------------------------|
| Linux    | `libproj`, `libproj.so.{version}`                   |
| macOS    | `libproj`, `libproj.{version}`                      |
| MinGW    | `libproj`, `libproj-{version}`                      |
| MSVC     | `libproj`, `proj_{version}`                         |

The unversioned `libproj` entry is always included as a fallback.

## Library Versions

C shared libraries use version suffixes that vary by platform and change across releases. `library_versions` lets you list known version suffixes so FFI can find whichever version is installed.

For example, the [PROJ](https://proj.org/) coordinate transformation library has used these version suffixes across releases:

```yaml
library_names:
  - proj
library_versions:
  - "25"    # PROJ 9.2
  - "22"    # PROJ 8.x
  - "19"    # PROJ 7.x
  - "17"    # PROJ 6.1, 6.2
  - "15"    # PROJ 6.0
```

This generates search names like `libproj.so.25`, `libproj.so.22`, etc. on Linux, `libproj.25` on macOS, `libproj-25` on MinGW, and `proj_25` on MSVC. The loader sorts the version suffixes in descending order before emitting them, so newer versions are tried first.

If `library_versions` is omitted, only the unversioned name is searched. This works on most systems where the package manager creates an unversioned symlink (e.g., `libproj.so` → `libproj.so.25`).

## Library Search Path

If the library is installed outside standard operating system search paths, use `library_search_path`:

```yaml
library_names:
  - proj
library_search_path: PROJ_LIB_PATH
```

This generates loader code that checks `ENV["PROJ_LIB_PATH"]` at runtime and prepends that directory to every generated search name before falling back to the default search list.
