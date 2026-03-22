# encoding: UTF-8

require_relative './rice_abstract_test'

class SignatureBuilderTest < RiceAbstractTest
  def test_builds_buffer_arguments_and_qualified_defaults
    parsed, collaborators = parse_cpp(<<~CPP)
      namespace Tests {
        struct Widget {
          Widget(const char *);
          static Widget named(const char *);
        };

        void use_buffer(int *values, Widget value = Widget::named("Widget"));
      }
    CPP

    signature_builder = collaborators[:signature_builder]
    function_cursor = find_cursor(parsed.translation_unit.cursor, :cursor_function, "use_buffer")
    args = signature_builder.arguments(function_cursor)

    assert signature_builder.buffer_type?(function_cursor.argument(0).type)
    assert_equal 'ArgBuffer("values")', args[0]
    assert_includes args[1], 'Tests::Widget::named("Widget")'
    assert_equal '<void(*)(int *, Tests::Widget)>', signature_builder.method_signature(function_cursor)
  end
end
