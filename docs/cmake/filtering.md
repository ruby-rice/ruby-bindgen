# Filtering

## Skipping Files

The CMake config supports a `skip` option to exclude specific `*-rb.cpp` files from the generated `CMakeLists.txt`. However, in most cases it's better to add skip patterns to your Rice config instead — that way the problematic files are never generated, and CMake won't find them to include. The CMake `skip` is useful as a quick fix when you have stale generated files on disk that you don't want to recompile.
