# Updating Bindings

After generating bindings with `ruby-bindgen`, you'll need to regenerate them periodically as the upstream library evolves, `ruby-bindgen` improves, or you upgrade dependencies. This document covers strategies for managing that process.

All examples below reference the [opencv-ruby](https://github.com/ruby-rice/opencv-ruby) project, which wraps OpenCV's ~350 generated files and is a good real-world reference.

## Regenerate and Done

The best case. Run `ruby-bindgen` again and the new output compiles and works:

```bash
ruby-bindgen bindings.yaml
```

This works when:
- You're updating `ruby-bindgen` (bug fixes, new features) and don't have manual changes
- The upstream library's API didn't change in ways that break compilation
- Your bindings are simple enough that `ruby-bindgen` handles everything

If this is your situation, you're done. The sections below are for when you have [customizations](cpp/customizing.md) that need to be preserved across regenerations.

## Preserving Refinements

[Refinements](cpp/customizing.md#refinements-separate-manual-code) live in a separate directory that `ruby-bindgen` never touches. They survive regeneration automatically - no action needed.

## Preserving Manual Edits

If you have [manual edits](cpp/customizing.md#manual-edits) to generated files, you need a way to reapply them after regeneration. There are two approaches:

### Option A: Diff File

Maintain a unified diff file that can be reapplied after regeneration:

```bash
# After making all manual changes to generated files
git diff -- ext/ ':(exclude)ext/manual_updates.md' > ext/manual_updates.diff
```

After regenerating:

```bash
# Regenerate
ruby-bindgen bindings.yaml

# Reapply manual changes
cd ext/
git apply manual_updates.diff
```

**Pros**: Simple, standard tooling, machine-readable.

**Cons**: Diffs are fragile. If `ruby-bindgen`'s output changes line numbers or formatting, the diff won't apply cleanly. You'll need to manually resolve failures and regenerate the diff.

### Option B: Instruction File

Maintain a structured document (`manual_updates.md`) that describes each change declaratively. An AI assistant or a human can follow the instructions after each regeneration.

Here's how opencv-ruby structures its `manual_updates.md`:

#### Missing Includes

A table mapping files to required manual includes:

```markdown
## Manual Includes

| File                                     | Manual Includes                                          |
|------------------------------------------|----------------------------------------------------------|
| `opencv2/core/bindings_utils-rb.cpp`     | `<opencv2/core.hpp>`                                     |
| `opencv2/core/mat-rb.cpp`               | `<opencv2/core/cuda.hpp>`, `<opencv2/core/opengl.hpp>`   |
| `opencv2/core/saturate-rb.cpp`          | `<algorithm>`, `<climits>`                               |
| `opencv2/flann/flann_base-rb.cpp`       | `<opencv2/core/base.hpp>`, `<opencv2/flann/defines.h>`   |
```

#### Namespace Cleanup

```markdown
## DNN Module

| File                                     | Change                                                   |
|------------------------------------------|----------------------------------------------------------|
| `opencv2/dnn/*.cpp`, `opencv2/dnn/*.hpp` | Replace `::dnn4_v\d+` with empty string                  |
| `opencv2/dnn/*.cpp`, `opencv2/dnn/*.hpp` | Replace `Dnn4V\d+` with empty string in variable names   |
| `opencv2/dnn/*.cpp`                      | Delete `Module rb_mCvDnn = define_module_under(..., "");` |
```

#### Version Guards

Specific line ranges to wrap with `#if` guards:

```markdown
## OpenCV Version Guards

### `opencv2/core/bindings_utils-rb.cpp`
- **Line ~38**: `dump_int64` (>= 407)
- **Line ~113**: `dump_vec2i` through `ClassWithKeywordProperties` (>= 407)
- **Line ~124**: `FunctionParams` class (>= 408)

### `opencv2/core/cvdef-rb.cpp`
- **Line ~73**: `CV_CPU_NEON_DOTPROD` constant (>= 407)
- **Line ~77**: `CV_CPU_NEON_FP16`, `CV_CPU_NEON_BF16` constants (>= 409)
```

**Pros**: Survives large formatting changes, human-readable, an AI assistant can apply the instructions even when line numbers shift.

**Cons**: Requires more effort to write initially. Must be kept in sync with actual changes.

### Combining Both Approaches

opencv-ruby maintains both files:

- `manual_updates.md` - the authoritative description of what changes are needed and why
- `manual_updates.diff` - a snapshot of the actual changes for quick verification

After regeneration:
1. Try applying the diff (`git apply manual_updates.diff`)
2. If it fails, use `manual_updates.md` as a guide (manually or with AI)
3. After all changes are applied, regenerate the diff:
   ```bash
   git diff -- ext/ ':(exclude)ext/manual_updates.md' > ext/manual_updates.diff
   ```

## Recommended Workflow

For ongoing maintenance after an upstream library update:

```bash
# 1. Regenerate
ruby-bindgen bindings.yaml

# 2. Try building
cmake --preset linux-debug && cmake --build build/linux-debug

# 3. If it compiles, done. If not:
#    - Missing includes? Add to manual_updates.md and apply
#    - Linker errors? Comment out and document
#    - New API version issues? Add version guards
#    - Need custom methods? Add to refinements/

# 4. Update the diff file
git diff -- ext/ ':(exclude)ext/manual_updates.md' > ext/manual_updates.diff
```

## Tips

- **Keep `manual_updates.md` up to date** - it's the source of truth when diffs fail to apply
- **Refinements survive automatically** - only manual edits to generated files need tracking
- **Try building early** - regenerate, build, and fix incrementally rather than trying to predict all issues upfront
