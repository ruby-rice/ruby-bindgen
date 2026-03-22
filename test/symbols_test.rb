# encoding: UTF-8

require_relative './rice_abstract_test'

class SymbolsTest < RiceAbstractTest
  def test_build_candidates_includes_fully_qualified_template_argument_candidates
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

    candidates = RubyBindgen::Symbols.new.build_candidates(cursor)

    assert_includes candidates, "Holder<Outer::Tag>"
    assert_includes candidates, "Outer::Holder<Outer::Tag>"
  end

  def test_build_candidates_preserves_non_type_args_when_qualifying_class_specializations
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

    candidates = RubyBindgen::Symbols.new.build_candidates(cursor)

    assert_includes candidates, "Holder<Outer::Tag, 7>"
    assert_includes candidates, "Outer::Holder<Outer::Tag, 7>"
  end

  def test_build_candidates_includes_fully_qualified_typedef_alias_parameter_candidates
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
    candidates = RubyBindgen::Symbols.new.build_candidates(cursor)

    assert_includes candidates, "takeAlias(Outer::HolderTag)"
    assert_includes candidates, "Outer::takeAlias(Outer::HolderTag)"
  end

  def test_build_candidates_includes_non_type_function_template_specialization_candidates
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

    candidates = RubyBindgen::Symbols.new.build_candidates(cursor)

    assert_includes candidates, "takeValue<7>()"
    assert_includes candidates, "Outer::takeValue<7>()"
  end
end
