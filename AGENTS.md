# Agent Instructions

## About ruby-bindgen

For ruby-bindgen features and capabilities, see the `docs/` directory
(classes, methods, enums, templates, default_values, filtering,
include_header, operators, iterators).
For configuration options, see [docs/configuration.md](docs/configuration.md).

## Key Files

- `lib/ruby-bindgen/generators/generator.rb` - Base class for all generators
- `lib/ruby-bindgen/generators/rice/rice.rb` - Rice generator that walks the AST
- `lib/ruby-bindgen/generators/rice/*.erb` - ERB templates that generate Rice C++ code
- `test/headers/cpp/*.hpp` - Test input headers
- `test/bindings/cpp/*-rb.cpp` - Expected output (golden files)

## Skills

Task-specific procedures live as [Agent Skills](https://agentskills.io) under
`.agent/skills/`:

- [running-tests](.agent/skills/running-tests/SKILL.md) — run rice_test and
  cmake_test, fully or by name. Read-only.
- [update-expected-output](.agent/skills/update-expected-output/SKILL.md) —
  regenerate golden files in `test/bindings/cpp/` with `UPDATE_EXPECTED=1`.
- [bug-fix-workflow](.agent/skills/bug-fix-workflow/SKILL.md) — test-first
  workflow, no-mocks / no-Rice-workarounds rules, typedef test layout.

The opencv-ruby regeneration workflow lives in that project's skills folder
at `../opencv-ruby/.agent/skills/regenerate-opencv-bindings/SKILL.md`.

## Git Commits

One commit per fix. Do not batch multiple unrelated fixes into a single
commit.

Do not add Co-Authored-By or any other author attribution to commit messages.
