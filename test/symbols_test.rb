# encoding: UTF-8

require_relative './rice_test_base'

# Tests for the policy/lookup layer of Symbols. The candidate-name enumeration
# itself lives in SymbolCandidates and is tested in symbol_candidates_test.rb.
class SymbolsTest < RiceAbstractTest
  def test_skip_matches_qualified_name
    parsed, = parse_cpp(<<~CPP)
      namespace Outer {
        void hidden();
        void visible();
      }
    CPP

    symbols = RubyBindgen::Symbols.new(skip: ["Outer::hidden"])

    hidden = find_cursor(parsed.translation_unit.cursor, :cursor_function, "hidden")
    visible = find_cursor(parsed.translation_unit.cursor, :cursor_function, "visible")

    assert symbols.skip?(hidden), "Outer::hidden should be skipped"
    refute symbols.skip?(visible), "Outer::visible should not be skipped"
  end

  def test_skip_matches_via_regex
    parsed, = parse_cpp(<<~CPP)
      namespace Outer {
        void internalFoo();
        void publicBar();
      }
    CPP

    symbols = RubyBindgen::Symbols.new(skip: ["/^Outer::internal/"])

    internal = find_cursor(parsed.translation_unit.cursor, :cursor_function, "internalFoo")
    public_fn = find_cursor(parsed.translation_unit.cursor, :cursor_function, "publicBar")

    assert symbols.skip?(internal), "Outer::internalFoo should match /^Outer::internal/"
    refute symbols.skip?(public_fn), "Outer::publicBar should not match"
  end

  def test_skip_normalizes_pointer_whitespace
    # User writes `const int*` (no space); clang emits parameter spelling as
    # `const int *`. Both must canonicalize so the lookup hits.
    parsed, = parse_cpp(<<~CPP)
      void take_ptr(const int* p);
    CPP

    symbols = RubyBindgen::Symbols.new(skip: ["take_ptr(const int*)"])
    cursor = find_cursor(parsed.translation_unit.cursor, :cursor_function, "take_ptr")

    assert symbols.skip?(cursor), "take_ptr(const int*) should match against `const int *`"
  end

  def test_version_returns_guard_value
    parsed, = parse_cpp(<<~CPP)
      namespace Outer {
        void newApi();
      }
    CPP

    symbols = RubyBindgen::Symbols.new(versions: { 30000 => ["Outer::newApi"] })
    cursor = find_cursor(parsed.translation_unit.cursor, :cursor_function, "newApi")

    assert_equal 30000, symbols.version(cursor)
    assert symbols.has_versions?
  end

  def test_override_returns_signature_string
    parsed, = parse_cpp(<<~CPP)
      int do_thing(int n);
    CPP

    symbols = RubyBindgen::Symbols.new(overrides: { "do_thing" => "[:int], :bool" })
    cursor = find_cursor(parsed.translation_unit.cursor, :cursor_function, "do_thing")

    assert_equal "[:int], :bool", symbols.override(cursor)
  end

  def test_skip_spelling_fallback_for_dependent_types
    # skip_spelling? is the fallback for types that have no declaration cursor
    # (dependent / unexposed types), so we test the bare API rather than a real
    # cursor.
    symbols = RubyBindgen::Symbols.new(skip: ["Internal::HiddenType", "/^Banned/"])

    assert symbols.skip_spelling?("std::vector<Internal::HiddenType>"),
           "exact-name skip should match against a substring with word boundaries"
    assert symbols.skip_spelling?("BannedThing"),
           "regex skip should match"
    refute symbols.skip_spelling?("std::vector<UnrelatedType>"),
           "unrelated spellings should not match"
    refute symbols.skip_spelling?("HiddenTypeNotInternal"),
           "word-boundary should prevent a non-namespaced partial match"
  end
end
