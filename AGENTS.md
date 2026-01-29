# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## About ruby-bindgen
For ruby-bindgen features and capabilities, see [docs/features.md](docs/features.md).
For configuration options, see [docs/configuration.md](docs/configuration.md).

## Key Files

- `lib/ruby-bindgen/visitors/rice/rice.rb` - Main visitor that walks the AST
- `lib/ruby-bindgen/visitors/rice/*.erb` - ERB templates that generate Rice C++ code
- `test/headers/cpp/*.hpp` - Test input headers
- `test/bindings/cpp/*-rb.cpp` - Expected output (golden files)

## Running Tests

```bash
# Run all tests
bundle exec ruby -Ilib -Itest test/rice_test.rb

# Run a specific test
bundle exec ruby -Ilib -Itest test/rice_test.rb --name test_classes

# Regenerate expected files after making changes
UPDATE_EXPECTED=1 bundle exec ruby -Ilib -Itest test/rice_test.rb
```

All 15 tests: classes, enums, functions, inheritance, templates, constructors, operators, default_values, iterators, template_inheritance, overloads, incomplete_types, filtering, template_defaults, buffers

## Regenerate opencv-ruby bindings

See `/mnt/c/Source/opencv-ruby/ext/bindings.yaml` for the full configuration. Use the match field to configure what *.h/*.hpp files are processed and thus generate bindings for.   

```bash
# Generate bindings
cd /mnt/c/Source/ruby-bindgen
bundle exec ruby -Ilib bin/ruby-bindgen /mnt/c/Source/opencv-ruby/ext/bindings.yaml
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

