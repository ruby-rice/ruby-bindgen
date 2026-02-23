# Updating Bindings

After generating bindings with `ruby-bindgen`, you'll need to regenerate them periodically as the upstream library evolves, `ruby-bindgen` improves, or you upgrade dependencies. This document covers strategies for managing that process.

## Simple Case

If you have no [customizations](cpp/customizing.md) to preserve, then you can simply regenerate the bindings:

```bash
ruby-bindgen bindings.yaml
```

In most cases, the updated bindings should compile and work.

The rest of this page discusses strategies for more complex cases where you want to preserve [customizations](cpp/customizing.md) when regenerating bindings.

## Preserving Refinements

[Refinements](cpp/customizing.md#refinements-separate-manual-code) live in a separate directory that `ruby-bindgen` never touches, so the source files survive regeneration automatically. However, the top-level `-rb.cpp` file is regenerated, so you will need to re-add the `#include` directives and `Init_*_Refinement` calls.

## Preserving Manual Edits

If you have [manual edits](cpp/customizing.md#manual-edits) to generated files, you need a way to reapply them after regeneration. Two possible approaches include:

### Option A: Diff File

Maintain a diff file that can be reapplied after regeneration:

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

### Option B: Agent File

Maintain a structured document (`manual_updates.md`) that describes each change declaratively. An AI assistant or a human can follow the instructions after each regeneration. For an example, see opencv-ruby's [manual_updates.md](https://github.com/ruby-rice/opencv-ruby/blob/main/ext/manual_updates.md).

**Pros**: Survives large formatting changes, human-readable, an AI assistant can apply the instructions even when line numbers shift.

**Cons**: Must be kept in sync with actual changes.

