# encoding: UTF-8

require_relative './rice_test_base'

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

  def test_constructor_signatures_decay_array_parameters_and_array_typedefs
    parsed, collaborators = parse_cpp(<<~CPP)
      namespace Tests {
        struct MatND {
          typedef int SizeArray[2];
          typedef int StepArray[2];

          MatND(SizeArray size, int type);
          MatND(SizeArray size, int type, void *data, StepArray step);
        };

        struct CommandLineStyle {
          CommandLineStyle(int argc, const char *const argv[], bool enabled);
        };
      }
    CPP

    signature_builder = collaborators[:signature_builder]
    constructors = parsed.translation_unit.cursor.find_by_kind(true, :cursor_constructor)

    matnd_simple = constructors.find { |cursor| cursor.semantic_parent.spelling == "MatND" && cursor.num_arguments == 2 }
    refute_nil matnd_simple
    assert_equal "Tests::MatND, int *, int", signature_builder.constructor_signature(matnd_simple)

    matnd_buffer = constructors.find { |cursor| cursor.semantic_parent.spelling == "MatND" && cursor.num_arguments == 4 }
    refute_nil matnd_buffer
    assert_equal "Tests::MatND, int *, int, void *, int *", signature_builder.constructor_signature(matnd_buffer)

    command_line = constructors.find { |cursor| cursor.semantic_parent.spelling == "CommandLineStyle" }
    refute_nil command_line
    assert_equal "Tests::CommandLineStyle, int, const char *const *, bool",
                 signature_builder.constructor_signature(command_line)
  end
end
