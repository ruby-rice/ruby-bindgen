# encoding: UTF-8

require_relative './rice_abstract_test'

class ReferenceQualifierTest < RiceAbstractTest
  def test_qualifies_defaults_without_touching_string_literals
    parsed, collaborators = parse_cpp(<<~CPP)
      namespace quoted {
        struct Widget {
          Widget(const char *);
          static Widget named(const char *);
        };

        Widget helper(const char *);

        void from_helper(Widget value = helper("helper"));
        void from_ctor(Widget value = Widget("Widget"));
      }
    CPP

    qualifier = collaborators[:reference_qualifier]
    from_helper = find_cursor(parsed.translation_unit.cursor, :cursor_function, "from_helper")
    helper_param = from_helper.argument(0)
    helper_default_text, helper_offset = qualifier.extract_default_text(helper_param)
    helper_expr = find_default_expression(helper_param)

    assert_equal 'helper("helper")', helper_default_text
    assert_equal 'quoted::helper("helper")',
                 qualifier.qualify_source_references(helper_expr, helper_default_text, helper_offset)

    from_ctor = find_cursor(parsed.translation_unit.cursor, :cursor_function, "from_ctor")
    ctor_param = from_ctor.argument(0)
    ctor_default_text, ctor_offset = qualifier.extract_default_text(ctor_param)
    ctor_expr = find_default_expression(ctor_param)

    assert_equal 'Widget("Widget")', ctor_default_text
    assert_equal 'quoted::Widget("Widget")',
                 qualifier.qualify_source_references(ctor_expr, ctor_default_text, ctor_offset)
  end
end
