# encoding: UTF-8

require_relative './rice_abstract_test'

class NamerTest < RiceAbstractTest
  def test_rename_methods_matches_inline_namespace_collapsed_parent_type
    parsed, = parse_cpp(<<~CPP)
      namespace Outer {
        inline namespace guard_v1 {
          class Box {
          public:
            bool grab();
          };
        }
      }
    CPP

    cursor = find_cursor(parsed.translation_unit.cursor, :cursor_cxx_method, "grab")
    rename_methods = RubyBindgen::NameMapper.from_config([
      {"from" => "Outer::Box::grab", "to" => "grab"}
    ])
    namer = RubyBindgen::Namer.new(
      RubyBindgen::NameMapper.new,
      RubyBindgen::Generators::Rice::OPERATOR_MAPPINGS.merge(rename_methods),
      RubyBindgen::Generators::Rice::CONVERSION_TYPE_MAPPINGS
    )

    assert_equal "grab", namer.ruby(cursor)
  end
end
