# encoding: UTF-8

require 'tmpdir'
require 'fileutils'

require_relative './abstract_test'

class RiceComponentsTest < AbstractTest
  ParsedUnit = Struct.new(:dir, :parser, :translation_unit, :path)

  class TranslationUnitCapture
    attr_reader :translation_unit

    def visit_start
    end

    def visit_translation_unit(translation_unit, _path, _relative_path)
      @translation_unit = translation_unit
    end

    def visit_end
    end
  end

  def setup
    @parsed_units = []
  end

  def teardown
    @parsed_units.each do |parsed|
      FileUtils.remove_entry(parsed.dir) if parsed.dir && Dir.exist?(parsed.dir)
    end
  end

  def test_type_index_builds_typedef_and_qualified_name_lookups
    parsed, collaborators = parse_cpp(<<~CPP)
      namespace Example {
        using MyInt = int;
        template<typename T> struct Box {};
      }
    CPP

    type_index = collaborators[:type_index]
    assert_equal "Example::Box", type_index.qualified_name_for("Box")
    assert_equal "MyInt", type_index.typedef_for("int").spelling
  end

  def test_reference_qualifier_qualifies_defaults_without_touching_string_literals
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

  def test_type_speller_qualifies_class_static_members
    parsed, collaborators = parse_cpp(<<~CPP)
      namespace Tests {
        template<typename T, int Size> struct FixedBuffer {};

        template<int N>
        struct StaticSized {
          static constexpr int Size = N;
        };
      }
    CPP

    class_cursor = find_cursor(parsed.translation_unit.cursor, :cursor_class_template, "StaticSized")
    assert_equal "FixedBuffer<int, Tests::StaticSized<N>::Size>",
                 collaborators[:type_speller].qualify_class_static_members("FixedBuffer<int, Size>", class_cursor)
  end

  def test_template_resolver_fills_defaults_and_resolves_base_instantiations
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

  def test_signature_builder_builds_buffer_arguments_and_qualified_defaults
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

  private

  def parse_cpp(source)
    dir = Dir.mktmpdir("rice-components")
    path = File.join(dir, "fixture.hpp")
    File.write(path, source)

    config = load_config(File.join(__dir__, "headers", "cpp"))
    inputter = RubyBindgen::Inputter.new(dir, ["fixture.hpp"])
    parser = RubyBindgen::Parser.new(inputter, config[:clang_args], libclang: config[:libclang])
    capture = TranslationUnitCapture.new
    capture_io { parser.generate(capture) }

    parsed = ParsedUnit.new(dir, parser, capture.translation_unit, path)
    @parsed_units << parsed

    [parsed, build_collaborators(parsed, config)]
  end

  def build_collaborators(parsed, config)
    rename_types = RubyBindgen::NameMapper.from_config((config[:symbols] || {})[:rename_types] || [])
    rename_methods = RubyBindgen::Generators::Rice::OPERATOR_MAPPINGS.merge(
      RubyBindgen::NameMapper.from_config((config[:symbols] || {})[:rename_methods] || [])
    )
    namer = RubyBindgen::Namer.new(rename_types, rename_methods,
                                   RubyBindgen::Generators::Rice::CONVERSION_TYPE_MAPPINGS)
    FFI::Clang::Cursor.namer = namer

    type_index = RubyBindgen::Generators::TypeIndex.new
    type_index.build!(parsed.translation_unit.cursor)

    reference_qualifier = RubyBindgen::Generators::ReferenceQualifier.new
    type_speller = RubyBindgen::Generators::TypeSpeller.new(type_index: type_index)
    type_speller.printing_policy = parsed.translation_unit.cursor.printing_policy

    inputter = RubyBindgen::Inputter.new(parsed.dir, ["fixture.hpp"])
    rice = RubyBindgen::Generators::Rice.new(inputter, create_outputter("cpp"), config)

    {
      reference_qualifier: reference_qualifier,
      signature_builder: RubyBindgen::Generators::SignatureBuilder.new(
        type_speller: type_speller,
        reference_qualifier: reference_qualifier,
        copyable_type: rice.method(:copyable_type?),
        cursor_literals: RubyBindgen::Generators::Rice::CURSOR_LITERALS,
        fundamental_types: RubyBindgen::Generators::Rice::FUNDAMENTAL_TYPES
      ),
      template_resolver: RubyBindgen::Generators::TemplateResolver.new(
        reference_qualifier: reference_qualifier,
        type_speller: type_speller,
        namer: namer
      ),
      type_index: type_index,
      type_speller: type_speller
    }
  end

  def find_cursor(root, kind, spelling)
    cursor = root.find_by_kind(true, kind).find { |child| child.spelling == spelling }
    refute_nil cursor, "Expected to find #{kind} #{spelling}"
    cursor
  end

  def find_default_expression(param)
    default_value_kinds = [:cursor_unexposed_expr, :cursor_call_expr, :cursor_decl_ref_expr,
                           :cursor_c_style_cast_expr, :cursor_cxx_static_cast_expr,
                           :cursor_cxx_functional_cast_expr, :cursor_cxx_typeid_expr,
                           :cursor_paren_expr] + RubyBindgen::Generators::Rice::CURSOR_LITERALS
    param.find_by_kind(false, *default_value_kinds).find do |expr|
      if expr.kind == :cursor_decl_ref_expr
        ref = expr.referenced
        ref && ref.kind != :cursor_non_type_template_parameter && ref.kind != :cursor_template_type_parameter
      else
        true
      end
    end
  end
end
