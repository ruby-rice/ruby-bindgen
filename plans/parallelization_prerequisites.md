# Parallelization Prerequisites

This is a concrete refactor plan for removing the current architectural blockers
that make later parallelization harder.

It is deliberately **not** a parallel execution plan. It does not choose
processes vs threads vs Ractors, and it does not propose `--jobs`, worker pools,
IPC, or scheduling.

## Non-Goals

- Do not implement parallel execution yet.
- Do not change the external CLI for concurrency in this work.
- Do not mix in unrelated generator bug fixes.
- Do not change the CMake generator yet unless a Rice refactor forces it.

## Current Blockers

Today the Rice generator has several serial-only assumptions:

- naming depends on process-global `FFI::Clang::Cursor.namer`
- shared project metadata is accumulated as mutable generator state
- translation-unit-local state and run-global state live in the same instance
  variables
- ordering is implicit and partly dependent on traversal order
- parser/generator progress is written directly to `STDOUT`

The goal of the changes below is to make the serial code explicit and
deterministic first, so a later parallel implementation can reuse the same
boundaries.

## Refactor 1: Remove `Cursor.namer`

### Problem

`lib/ruby-bindgen/refinements/cursor.rb` currently stores the active `Namer` in a
class instance variable on `FFI::Clang::Cursor`, and the generator sets it in
`lib/ruby-bindgen/generators/rice/rice.rb`:

- `FFI::Clang::Cursor.namer=`
- `FFI::Clang::Cursor#ruby_name`
- `FFI::Clang::Cursor#cruby_name`
- `Rice#generate` assigns the global before parsing

That is global mutable state for something that is really generator-local.

### Code Changes

1. In `lib/ruby-bindgen/refinements/cursor.rb`:
   - delete `self.namer`
   - delete `self.namer=`
   - delete `ruby_name`
   - delete `cruby_name`
   - keep `anonymous_definer`

2. In `lib/ruby-bindgen/generators/rice/rice.rb`, replace direct cursor naming
   calls with direct use of `@namer`:
   - `cursor.ruby_name`
   - `cursor.cruby_name`
   - `cursor.semantic_parent.cruby_name`
   - `under.cruby_name`

3. Update ERB templates to stop reaching into cursor-global naming state. The
   call sites are:
   - `lib/ruby-bindgen/generators/rice/class.erb`
   - `lib/ruby-bindgen/generators/rice/union.erb`
   - `lib/ruby-bindgen/generators/rice/namespace.erb`
   - `lib/ruby-bindgen/generators/rice/enum_decl.erb`
   - `lib/ruby-bindgen/generators/rice/field_decl.erb`
   - `lib/ruby-bindgen/generators/rice/variable.erb`
   - `lib/ruby-bindgen/generators/rice/constant.erb`
   - `lib/ruby-bindgen/generators/rice/incomplete_class.erb`
   - `lib/ruby-bindgen/generators/rice/class_template_specialization.erb`
   - `lib/ruby-bindgen/generators/rice/function.erb`

4. Expose `namer` to templates rather than adding thin wrapper helpers on the
   generator. For simple current-cursor naming inside ERB, use:

   ```erb
   <%= namer.ruby(cursor) %>
   <%= namer.cruby(cursor) %>
   ```

5. Pass explicit locals only for names that are contextual or derived, not just
   "the Ruby name of this cursor". For example, instead of forcing every name
   through locals:

   ```erb
   <%= namer.cruby(cursor) %>
   ```

   pass locals only where the template needs something more specific:

   ```ruby
   render_cursor(cursor, "class",
     ruby_class_name: ruby_class_name,
     under_cruby_name: under ? @namer.cruby(under) : nil,
     ...)
   ```

### Test Changes

- Update `test/rice_abstract_test.rb` to stop setting `FFI::Clang::Cursor.namer`.
- Extend `test/rice_generator_test.rb` with a direct unit test that a
  `Rice` instance can compute names without any global cursor setup.

## Refactor 2: Make Input Enumeration Explicit and Sorted

### Problem

`lib/ruby-bindgen/inputter.rb` currently yields files directly from nested
`Dir.glob` loops. That works serially, but there is no single canonical ordered
input list that the rest of the system can reuse.

### Code Changes

This refactor should happen **after** `BindingPaths` is in place. It is useful,
but it is not the highest-leverage first step, because `BindingPaths` can be
derived from the existing `(path, relative_path)` pairs today.

1. In `lib/ruby-bindgen/inputter.rb`, add a small plain class:

   ```ruby
   class HeaderFile
     attr_reader :path, :relative_path

     def initialize(path:, relative_path:)
       @path = path
       @relative_path = relative_path
     end
   end

   def files
     ...
   end
   ```

2. `files` should:
   - expand all globs
   - apply excludes
   - deduplicate
   - return `HeaderFile` objects
   - sort once by `relative_path`

3. Change `Inputter#each` to delegate to `files.each` so the rest of the code
   gets the same deterministic order without rewriting all callers at once.

4. Change `lib/ruby-bindgen/parser.rb` to iterate `inputter.files` instead of
   reconstructing ordering implicitly through `each`.

5. If introducing `HeaderFile` turns out to be more ceremony than value, keep
   the canonical `files` list but allow it to return `[path, relative_path]`
   pairs first. The important part is one ordered reusable list, not the wrapper
   object.

### Test Changes

- Add `test/inputter_test.rb`.
- Cover:
  - dedup across multiple globs
  - exclude handling
  - final ordering by `relative_path`

## Refactor 3: Extract Pure Per-Header Binding Paths

### Problem

`visit_translation_unit` in `lib/ruby-bindgen/generators/rice/rice.rb` computes
file names and init names inline and also mutates `@init_names`, `@basename`,
and `@relative_dir`.

What is pure here is the path and naming plan derived from `relative_path`, not
the final emitted file set. In particular, `.ipp` naming is pure, but whether a
`.ipp` file is actually written depends on the parsed translation unit.

### Code Changes

1. In `lib/ruby-bindgen/generators/rice/rice.rb`, add a small plain class:

   ```ruby
   class BindingPaths
     attr_reader :relative_path, :relative_dir, :basename,
                 :hpp_path, :cpp_path, :ipp_path,
                 :init_name, :relative_include_header

     def initialize(...)
       ...
     end
   end
   ```

2. Extract the inline logic from `visit_translation_unit` into:

   ```ruby
   def build_binding_paths(relative_path)
     ...
   end
   ```

3. Move the current init-name logic into a pure helper:

   ```ruby
   def init_name_for(relative_path)
     ...
   end
   ```

   This is the code currently embedded around `Rice#visit_translation_unit`
   lines 309-315.

4. Move generated file name construction into pure helpers:

   ```ruby
   def binding_basename_for(relative_path)
     ...
   end

   def binding_paths_for(relative_path)
     ...
   end
   ```

5. Change `visit_translation_unit` to start with:

   ```ruby
   binding_paths = build_binding_paths(relative_path)
   ```

   and stop assigning:
   - `@basename`
   - `@relative_dir`
   - `@init_names[rice_header] = init_name`

6. Update `translation_unit.hpp.erb` and `translation_unit.cpp.erb` to receive
   either the full `binding_paths` object or explicit locals derived from it,
   instead of individually computed pieces from mutable instance variables.

7. Do not treat `BindingPaths#ipp_path` as meaning the `.ipp` file exists.
   `visit_translation_unit` should still decide whether to write `.ipp` based on
   `has_builders`.

### Test Changes

- Extend `test/rice_generator_test.rb` with direct tests for:
  - `init_name_for(relative_path)`
  - `build_binding_paths(relative_path)`
- Use real sample paths such as:
  - `opencv2/core/version.hpp`
  - `opencv2/dnn/version.hpp`
  - `opencv2/core/parallel/parallel_backend.hpp`

## Refactor 4: Replace Translation-Unit Instance Variables with a Context Object

### Problem

`Rice` currently reuses one generator instance across many headers and resets
translation-unit state manually at the top of `visit_translation_unit`:

- `@namespaces`
- `@classes`
- `@auto_generated_bases`
- `@non_member_operators`
- `@incomplete_iterators`
- `@class_iterator_names`
- `@includes`
- `@basename`
- `@relative_dir`

That makes it hard to tell what is really per-header and what is shared for the
whole run.

### Code Changes

1. Add a plain context class in `lib/ruby-bindgen/generators/rice/rice.rb`:

   ```ruby
   class TranslationContext
     attr_reader :binding_paths, :includes, :namespaces, :classes,
                 :auto_generated_bases, :non_member_operators,
                 :incomplete_iterators, :class_iterator_names

     def initialize(binding_paths:)
       @binding_paths = binding_paths
       @includes = Set.new
       @namespaces = Set.new
       @classes = {}
       @auto_generated_bases = Set.new
       @non_member_operators = Hash.new { |h, k| h[k] = [] }
       @incomplete_iterators = {}
       @class_iterator_names = Hash.new { |h, k| h[k] = Set.new }
     end
   end
   ```

2. Add:

   ```ruby
   def begin_translation_unit(binding_paths, cursor)
     @current = TranslationContext.new(...)
     @type_speller.printing_policy = cursor.printing_policy
     @type_index.build!(cursor)
   end

   def current
     @current or raise "translation-unit state not initialized"
   end
   ```

3. Replace direct use of these ivars with `current.*` accessors in the methods
   that mutate per-header state. The main methods to touch are:
   - `visit_translation_unit`
   - `visit_class_decl`
   - `visit_incomplete_class`
   - `visit_cxx_iterator_method`
   - `visit_namespace`
   - `visit_operator_non_member`
   - `render_non_member_operators`
   - `visit_typedef_decl`
   - `visit_template_specialization`
   - `auto_instantiate_template`
   - `auto_generate_base_class`

4. As a first step, add small wrapper helpers if needed:

   ```ruby
   def current_classes = current.classes
   def current_includes = current.includes
   ```

   Then migrate call sites to the wrappers before replacing all storage.

5. Clear `@current` at the end of `visit_translation_unit` so later code cannot
   accidentally read stale per-header state.

### Result

After this refactor, the only long-lived state on the generator should be:

- configuration
- helper objects (`@symbols`, `@type_speller`, `@template_resolver`, etc.)
- eventually, an explicit list of generated units if still needed for serial
  finalization

## Refactor 5: Stop Using `@init_names` as Shared Output State

### Problem

`@init_names` in `lib/ruby-bindgen/generators/rice/rice.rb` is a run-global hash
populated incidentally while translation units are generated. That means shared
project files depend on traversal side effects.

### Code Changes

1. Delete `@init_names` from `Rice#initialize`.

2. Change `create_project_files` to derive its data from the canonical input
   list:

   ```ruby
   binding_paths_list = @inputter.files.map do |header_file|
     build_binding_paths(header_file.relative_path)
   end
   ```

3. Sort `binding_paths_list` by `relative_path` before rendering.

4. Change `project.cpp.erb` to receive `binding_paths_list:` instead of
   `init_names:`. Update
   the template from:

   ```erb
   <% init_names.keys.each do |init_name| -%>
   #include "<%= init_name %>"
   <% end -%>
   ...
   <% init_names.values.each do |init_function| -%>
   ```

   to:

   ```erb
   <% binding_paths_list.each do |binding_paths| -%>
   #include "<%= binding_paths.hpp_path %>"
   <% end -%>
   ...
   <% binding_paths_list.each do |binding_paths| -%>
     <%= binding_paths.init_name %>();
   <% end -%>
   ```

5. `project.hpp.erb` can stay mostly unchanged; it only needs the top-level
   project init function.

### Test Changes

- Extend `test/rice_test.rb#test_project` or add a new generator-level test to
  verify:
  - shared project output is stable when match patterns are reordered
  - shared project output is built from input headers, not output directory scan

## Refactor 6: Make `.ipp` Include Ownership Dependent Only on `BindingPaths`

### Problem

Cross-file `.ipp` includes currently rely on `@relative_dir` and `@basename` as
implicit current-file state.

### Code Changes

1. Change:

   ```ruby
   current_ipp = File.join(@relative_dir, "#{@basename}.ipp")
   ```

   in `visit_template_specialization` to:

   ```ruby
   current_ipp = current.binding_paths.ipp_path
   ```

2. Change relative include computation from `@relative_dir` to
   `current.binding_paths.relative_dir`.

3. Update `ipp_path_for_cursor(cursor)` to return a generated path in the same
   format as `BindingPaths#ipp_path`.

4. Keep all `.ipp` path arithmetic in one place so later per-header workers do
   not need to rebuild the rules independently.

### Methods to Update

- `ipp_path_for_cursor`
- `visit_template_specialization`
- any future helper that computes `current_ipp`

## Refactor 7: Introduce a Reporter Instead of Writing to `STDOUT`

### Problem

These files currently print progress directly:

- `lib/ruby-bindgen/parser.rb`
- `lib/ruby-bindgen/generators/rice/rice.rb`

Direct `STDOUT` writes are acceptable in serial mode but are the wrong boundary
if later execution can overlap.

### Code Changes

1. Add `lib/ruby-bindgen/reporter.rb` with a minimal interface:

   ```ruby
   class Reporter
     def processing_start; end
     def processing_file(path); end
     def writing(path); end
     def preserving(path); end
   end
   ```

2. Add a default stdout implementation:

   ```ruby
   class StdoutReporter < Reporter
     ...
   end
   ```

3. Inject the reporter into `Parser`:

   ```ruby
   def initialize(inputter, clang_args, libclang: nil, reporter: StdoutReporter.new)
   ```

4. Inject or create the same reporter in `Rice#generate` when constructing the
   parser.

5. Replace:
   - `STDOUT << "\n" << "Processing:" << "\n"`
   - `STDOUT << "  " << path << "\n"`
   - `STDOUT << "  Writing: " << ...`
   - `STDOUT << "  Preserving: " << ...`

   with reporter calls.

### Test Changes

- Add `test/parser_test.rb` for reporter calls and ordered iteration.
- Add a small fake reporter in the test to capture events without relying on
  `capture_io`.

## Refactor 8: Keep Shared Output Ownership in One Phase

### Problem

The serial code already has the right idea, but it is not explicit enough:

- per-header outputs:
  - `*-rb.hpp`
  - `*-rb.cpp`
  - `*-rb.ipp`
- shared outputs:
  - `rice_include.hpp` or custom include
  - `<project>-rb.hpp`
  - `<project>-rb.cpp`

The code should make that ownership obvious.

### Code Changes

1. Add explicit helpers in `Rice`:

   ```ruby
   def write_translation_unit_files(unit, ...)
     ...
   end

   def write_shared_files
     create_rice_include_header
     create_project_files
   end
   ```

2. Make `visit_end` call only `write_shared_files`.

3. Keep all shared-file writes in:
   - `create_rice_include_header`
   - `create_project_files`

4. Do not let per-header code paths write or mutate shared project metadata.

## Refactor 9: Tighten Tests Around Determinism and Isolation

### Tests to Add

1. `test/inputter_test.rb`
   - canonical sorted `files`
   - dedup across globs
   - exclude behavior

2. `test/parser_test.rb`
   - parser iterates in `Inputter#files` order
   - parser emits reporter events instead of writing directly

3. `test/rice_generator_test.rb`
  - `init_name_for`
  - `build_binding_paths`
  - no dependency on `Cursor.namer`
  - repeated per-header generation in one process does not reuse stale
     translation-unit state

4. `test/rice_test.rb`
   - existing end-to-end goldens remain the regression backstop
   - `test_project` should assert stable ordering in generated project wrapper

## Suggested Order

1. `build_binding_paths` and `init_name_for`
   - do this against the existing `(path, relative_path)` flow
   - do not block on `HeaderFile`
2. replace `@init_names` with derived ordered binding paths
3. add `TranslationContext`
4. remove `Cursor.namer`
5. convert templates and `rice.rb` call sites to use `namer`
6. add canonical `Inputter#files`
   - introduce `HeaderFile` only if it is still pulling its weight
7. switch parser/generator to reporter abstraction
8. tighten tests around the extracted helpers and ordering rules

## Done Means

This prerequisite work is complete when:

- `FFI::Clang::Cursor` no longer stores generator runtime state
- every generated header has a pure `BindingPaths` plan derived from
  `relative_path`
- translation-unit-local mutable state is isolated behind `@current`
- shared project files are rendered from ordered input header files, not from
  side-effect accumulation
- parser/generator progress is routed through a reporter
- the existing serial output stays byte-for-byte compatible except for
  intentionally deterministic ordering fixes

At that point, adding actual parallel execution becomes an execution-policy
decision instead of a prerequisite cleanup effort.
