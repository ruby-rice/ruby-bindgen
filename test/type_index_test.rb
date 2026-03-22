# encoding: UTF-8

require_relative './rice_abstract_test'

class TypeIndexTest < RiceAbstractTest
  def test_builds_typedef_and_qualified_name_lookups
    _parsed, collaborators = parse_cpp(<<~CPP)
      namespace Example {
        using MyInt = int;
        template<typename T> struct Box {};
      }
    CPP

    type_index = collaborators[:type_index]
    assert_equal "Example::Box", type_index.qualified_name_for("Box")
    assert_equal "MyInt", type_index.typedef_for("int").spelling
  end
end
