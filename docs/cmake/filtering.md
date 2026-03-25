# Filtering

## Skipping Files

The CMake config supports a `skip` option to exclude specific `*-rb.cpp` files from the generated `CMakeLists.txt`. However, in most cases it's better to add skip patterns to your Rice config instead — that way the problematic files are never generated, and CMake won't find them to include. The CMake `skip` is useful as a quick fix when you have stale generated files on disk that you don't want to recompile.

## Guarding Files And Directories

Use `guards` when generated paths should remain on disk but only be compiled when a CMake condition is true.

```yaml
guards:
  OpenCV_HAS_CUDA:
    - opencv2/cuda*-rb.cpp
  TARGET OpenCV::dnn:
    - opencv2/dnn
```

Guard keys are emitted as raw `if(...)` conditions. Guard values may be exact paths or globs and may match generated directories and `*-rb.cpp` files.

- Matching directories are emitted inside guarded `add_subdirectory(...)` blocks.
- Matching `*-rb.cpp` files are emitted inside guarded `target_sources(...)` blocks.
- A guard pattern that matches nothing emits a warning.
- If the same path matches multiple guards, generation fails with an error.

Use `skip` for permanent exclusion. Use `guards` for conditional inclusion.
