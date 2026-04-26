# encoding: UTF-8

require_relative './rice_test_base'

class SymbolCandidatesTest < RiceAbstractTest
  def candidates_for(cursor)
    RubyBindgen::SymbolCandidates.new(cursor).to_a
  end

  def test_includes_fully_qualified_template_argument_candidates
    parsed, = parse_cpp(<<~CPP)
      namespace Outer {
        struct Tag {};

        template<typename T>
        class Holder {};

        template<>
        class Holder<Tag> {};
      }
    CPP

    cursor = parsed.translation_unit.cursor.find_by_kind(true, :cursor_class_decl).find do |child|
      child.display_name == "Holder<Tag>"
    end
    refute_nil cursor, "Expected to find Holder<Tag> specialization"

    candidates = candidates_for(cursor)

    assert_includes candidates, "Holder<Outer::Tag>"
    assert_includes candidates, "Outer::Holder<Outer::Tag>"
  end

  def test_preserves_non_type_args_when_qualifying_class_specializations
    parsed, = parse_cpp(<<~CPP)
      namespace Outer {
        struct Tag {};

        template<typename T, int N>
        struct Holder {};

        template<>
        struct Holder<Tag, 7> {};
      }
    CPP

    cursor = parsed.translation_unit.cursor.find_by_kind(true, :cursor_struct).find do |child|
      child.display_name == "Holder<Tag, 7>"
    end
    refute_nil cursor, "Expected to find Holder<Tag, 7> specialization"

    candidates = candidates_for(cursor)

    assert_includes candidates, "Holder<Outer::Tag, 7>"
    assert_includes candidates, "Outer::Holder<Outer::Tag, 7>"
  end

  def test_includes_fully_qualified_typedef_alias_parameter_candidates
    parsed, = parse_cpp(<<~CPP)
      namespace Outer {
        struct Tag {};

        template<typename T>
        struct Holder {};

        using HolderTag = Holder<Tag>;

        void takeAlias(HolderTag value);
      }
    CPP

    cursor = find_cursor(parsed.translation_unit.cursor, :cursor_function, "takeAlias")
    candidates = candidates_for(cursor)

    assert_includes candidates, "takeAlias(Outer::HolderTag)"
    assert_includes candidates, "Outer::takeAlias(Outer::HolderTag)"
  end

  def test_includes_non_type_function_template_specialization_candidates
    parsed, = parse_cpp(<<~CPP)
      namespace Outer {
        template<int N>
        int takeValue() { return N; }

        template<>
        int takeValue<7>() { return 7; }
      }
    CPP

    cursor = parsed.translation_unit.cursor.find_by_kind(true, :cursor_function).find do |child|
      child.display_name == "takeValue<>()"
    end
    refute_nil cursor, "Expected to find takeValue<7> specialization"

    candidates = candidates_for(cursor)

    assert_includes candidates, "takeValue<7>()"
    assert_includes candidates, "Outer::takeValue<7>()"
  end

  def test_preserves_inline_namespace_and_collapsed_parent_forms
    parsed, = parse_cpp(<<~CPP)
      namespace cv {
        namespace dnn {
          inline namespace dnn4_v20241223 {
            class Layer {
            public:
              void init();
            };
          }
        }
      }
    CPP

    cursor = find_cursor(parsed.translation_unit.cursor, :cursor_cxx_method, "init")
    candidates = candidates_for(cursor)

    assert_includes candidates, "cv::dnn::dnn4_v20241223::Layer::init()"
    assert_includes candidates, "cv::dnn::Layer::init()"
  end

  def test_strip_anonymous_scopes_from_qualified_names
    parsed, = parse_cpp(<<~CPP)
      namespace Outer {
        enum { Value = 1 };
      }
    CPP

    cursor = find_cursor(parsed.translation_unit.cursor, :cursor_enum_constant_decl, "Value")
    candidates = candidates_for(cursor)

    assert_includes candidates, "Outer::Value"
    refute candidates.any? { |candidate| candidate.include?("(unnamed enum") }
  end

  def test_fall_back_to_macro_spelling_when_qualified_name_is_invalid
    parsed, = parse_cpp(<<~CPP)
      #define INCLUDED_MACRO 100
    CPP

    cursor = find_cursor(parsed.translation_unit.cursor, :cursor_macro_definition, "INCLUDED_MACRO")
    candidates = candidates_for(cursor)

    assert_equal ["INCLUDED_MACRO"], candidates
  end

  def test_normalize_signature_collapses_whitespace_around_pointers_and_references
    # Clang spells `const T *` (space before *) but users may write `const T*`.
    # Both should canonicalize identically so a YAML entry matches the cursor.
    [
      ["const int *", "const int*"],
      ["const   int  *", "const int*"],
      ["std::vector<int> &", "std::vector<int>&"],
      [" int  *  *  ", "int**"],
    ].each do |input, expected|
      assert_equal expected, RubyBindgen::SymbolCandidates.normalize_signature(input),
                   "normalize_signature(#{input.inspect}) expected #{expected.inspect}"
    end
  end
end
