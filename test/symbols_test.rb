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
end
