# encoding: UTF-8

require_relative './rice_abstract_test'

class RiceGeneratorTest < RiceAbstractTest
  def test_template_specialization_target_finds_direct_and_aliased_specializations
    parsed, = parse_cpp(<<~CPP)
      namespace Tests {
        template<typename T>
        struct Point_ {};

        typedef Point_<int> Point2i;
        typedef Point2i Point;
      }
    CPP

    config = load_config(File.join(__dir__, "headers", "cpp"))
    inputter = RubyBindgen::Inputter.new(parsed.dir, ["fixture.hpp"])
    rice = RubyBindgen::Generators::Rice.new(inputter, create_outputter("cpp"), config)

    direct_typedef = find_cursor(parsed.translation_unit.cursor, :cursor_typedef_decl, "Point2i")
    direct_template, direct_type = rice.send(:template_specialization_target, direct_typedef)
    assert_equal "Point_", direct_template.spelling
    assert_equal "Point_<int>", direct_type.spelling

    alias_typedef = find_cursor(parsed.translation_unit.cursor, :cursor_typedef_decl, "Point")
    alias_template, alias_type = rice.send(:template_specialization_target, alias_typedef)
    assert_equal "Point_", alias_template.spelling
    assert_equal "Point_<int>", alias_type.spelling
  end

  def test_get_base_spelling_qualifies_dependent_types_inside_template_bases
    parsed, = parse_cpp(<<~CPP)
      namespace Tests {
        template<typename T>
        struct Traits {
          using type = T;
        };

        template<typename T>
        struct Base {};

        template<typename T>
        struct Derived : Base<typename Traits<T>::type> {};
      }
    CPP

    config = load_config(File.join(__dir__, "headers", "cpp"))
    inputter = RubyBindgen::Inputter.new(parsed.dir, ["fixture.hpp"])
    rice = RubyBindgen::Generators::Rice.new(inputter, create_outputter("cpp"), config)
    derived_template = find_cursor(parsed.translation_unit.cursor, :cursor_class_template, "Derived")

    assert_equal "Tests::Base<typename Tests::Traits<T>::type>",
                 rice.send(:get_base_spelling, derived_template)
  end
end
