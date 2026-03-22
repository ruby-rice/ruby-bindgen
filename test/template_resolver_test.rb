# encoding: UTF-8

require_relative './rice_abstract_test'

class TemplateResolverTest < RiceAbstractTest
  def test_fills_defaults_and_resolves_base_instantiations
    parsed, collaborators = parse_cpp(<<~CPP)
      namespace Support {
        struct Tag {};

        template<typename T>
        struct Base {};
      }

      namespace Tests {
        template<typename T, typename U = Support::Tag>
        struct Holder {};

        typedef Holder<int> HolderInt;

        template<typename T>
        struct Derived : Support::Base<T> {};

        typedef Derived<int> DerivedInt;
      }
    CPP

    resolver = collaborators[:template_resolver]

    holder_typedef = find_cursor(parsed.translation_unit.cursor, :cursor_typedef_decl, "HolderInt")
    holder_template = holder_typedef.find_first_by_kind(false, :cursor_template_ref).referenced
    assert_equal ["int", "Support::Tag"],
                 resolver.full_template_arguments(holder_typedef, holder_typedef.underlying_type, holder_template)

    derived_typedef = find_cursor(parsed.translation_unit.cursor, :cursor_typedef_decl, "DerivedInt")
    assert_equal "Support::Base<int>",
                 resolver.resolve_base_instantiation(derived_typedef, derived_typedef.underlying_type)
  end

  def test_preserves_mixed_template_argument_kinds
    parsed, collaborators = parse_cpp(<<~CPP)
      namespace Support {
        template<typename T>
        struct Wrap {};

        template<typename T, int N, template<typename> class C>
        struct Box {};
      }

      namespace Tests {
        typedef Support::Box<int, 1 + 2, Support::Wrap> ExprBox;
      }
    CPP

    resolver = collaborators[:template_resolver]
    expr_typedef = find_cursor(parsed.translation_unit.cursor, :cursor_typedef_decl, "ExprBox")
    box_template = expr_typedef.find_first_by_kind(false, :cursor_template_ref).referenced

    assert_equal ["int", "1 + 2", "Support::Wrap"],
                 resolver.full_template_arguments(expr_typedef, expr_typedef.underlying_type, box_template)
  end

  def test_fills_dependent_type_defaults_from_specialized_cursor_arguments
    parsed, collaborators = parse_cpp(<<~CPP)
      namespace Support {
        template<typename T>
        struct Base {};
      }

      namespace Tests {
        template<typename T, typename U = Support::Base<T>>
        struct Holder {};

        typedef Holder<int> HolderInt;
      }
    CPP

    resolver = collaborators[:template_resolver]
    holder_typedef = find_cursor(parsed.translation_unit.cursor, :cursor_typedef_decl, "HolderInt")
    holder_template = holder_typedef.underlying_type.declaration.specialized_template

    assert_equal ["int", "Support::Base<int>"],
                 resolver.full_template_arguments(holder_typedef, holder_typedef.underlying_type, holder_template)
  end
end
