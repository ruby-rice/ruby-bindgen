# Library Loading

FFI needs to find and load the C shared library at runtime. The `library_names` and `library_versions` configuration options control how `ruby-bindgen` generates the library search logic.

## Library Names

`library_names` specifies the base names of the shared library. The generated code prepends `lib` and appends the platform-appropriate suffix:

| Platform | `library_names: ["proj"]` searches for              |
|----------|-----------------------------------------------------|
| Linux    | `libproj`, `libproj.so.{version}`                   |
| macOS    | `libproj`, `libproj.{version}.dylib`                |
| Windows  | `libproj`, `libproj-{version}`, `libproj_{version}` |

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

This generates search names like `libproj.so.25`, `libproj.so.22`, etc. on Linux, `libproj.25.dylib` on macOS, and `libproj-25` on Windows. FFI tries each name in order until one succeeds. The unversioned `libproj` is always included as a fallback.

If `library_versions` is omitted, only the unversioned name is searched. This works on most systems where the package manager creates an unversioned symlink (e.g., `libproj.so` → `libproj.so.25`).
