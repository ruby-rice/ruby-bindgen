# encoding: UTF-8

require 'tmpdir'

require_relative './rice_test_base'

class RiceGeneratorTest < RiceAbstractTest
  def test_translation_unit_file_predicate_distinguishes_main_and_included_headers
    Dir.mktmpdir("generator-files") do |dir|
      File.write(File.join(dir, "included.hpp"), <<~CPP)
        namespace Tests {
          class Included {};
        }
      CPP
      File.write(File.join(dir, "fixture.hpp"), <<~CPP)
        #include "included.hpp"

        namespace Tests {
          class Local {};
        }
      CPP

      config = load_config(File.join(__dir__, "headers", "cpp"))
      inputter = RubyBindgen::Inputter.new(dir, ["fixture.hpp"])
      parser = RubyBindgen::Parser.new(inputter, config[:clang_args], libclang: config[:libclang])
      capture = TranslationUnitCapture.new
      capture_io { parser.generate(capture) }

      rice = RubyBindgen::Generators::Rice.new(inputter, create_outputter("cpp"), config)
      root = capture.translation_unit.cursor
      local_class = root.find_by_kind(true, :cursor_class_decl).find { |child| child.spelling == "Local" }
      included_class = root.find_by_kind(true, :cursor_class_decl).find { |child| child.spelling == "Included" }

      refute_nil local_class
      refute_nil included_class
      assert rice.send(:translation_unit_file?, local_class)
      refute rice.send(:translation_unit_file?, included_class)
    end
  end

  def test_intrinsic_type_strips_reference_pointer_and_cv_layers
    parsed, = parse_cpp(<<~CPP)
      namespace Tests {
        template<typename T>
        class Container {};

        class Item {};

        class Consumer {
        public:
          Consumer(Container<Item>* const& items);
        };
      }
    CPP

    config = load_config(File.join(__dir__, "headers", "cpp"))
    inputter = RubyBindgen::Inputter.new(parsed.dir, ["fixture.hpp"])
    rice = RubyBindgen::Generators::Rice.new(inputter, create_outputter("cpp"), config)
    rice.instance_variable_get(:@type_speller).printing_policy = parsed.translation_unit.cursor.printing_policy

    constructor = find_cursor(parsed.translation_unit.cursor, :cursor_constructor, "Consumer")
    unwrapped = constructor.argument(0).type.intrinsic_type

    assert_equal "Tests::Container<Tests::Item>",
                 rice.instance_variable_get(:@type_speller).type_spelling(unwrapped)
  end

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

  def test_auto_instantiate_parameter_templates_uses_semantic_template_for_alias_parameters
    parsed, = parse_cpp(<<~CPP)
      namespace Tests {
        template<typename T>
        class Container {
        public:
          T value;
        };

        class AliasItem {};

        class ConsumerAlias {
        public:
          using AliasContainer = Container<AliasItem>;
          ConsumerAlias(const AliasContainer& items);
        };
      }
    CPP

    config = load_config(File.join(__dir__, "headers", "cpp"))
    inputter = RubyBindgen::Inputter.new(parsed.dir, ["fixture.hpp"])
    rice = RubyBindgen::Generators::Rice.new(inputter, create_outputter("cpp"), config)
    rice.instance_variable_get(:@type_speller).printing_policy = parsed.translation_unit.cursor.printing_policy
    consumer_alias = find_cursor(parsed.translation_unit.cursor, :cursor_class_decl, "ConsumerAlias")

    auto_instantiated = rice.send(:auto_instantiate_parameter_templates, consumer_alias, nil)

    assert_includes auto_instantiated, "Container_instantiate<Tests::AliasItem>"
  end

  def test_visit_template_specialization_qualifies_non_type_function_arguments
    parsed, = parse_cpp(<<~CPP)
      namespace Tests {
        void callback_ints(int left, int right);

        template<void (*Fn)(int, int)>
        class FunctionTemplate
        {
        public:
          static void invoke();
        };

        typedef FunctionTemplate<callback_ints> FunctionTemplateCallback;
      }
    CPP

    config = load_config(File.join(__dir__, "headers", "cpp"))
    inputter = RubyBindgen::Inputter.new(parsed.dir, ["fixture.hpp"])
    rice = RubyBindgen::Generators::Rice.new(inputter, create_outputter("cpp"), config)
    rice.instance_variable_get(:@type_speller).printing_policy = parsed.translation_unit.cursor.printing_policy

    typedef_cursor = find_cursor(parsed.translation_unit.cursor, :cursor_typedef_decl, "FunctionTemplateCallback")
    cursor_template, underlying_type = rice.send(:template_specialization_target, typedef_cursor)

    rendered = rice.send(:visit_template_specialization, typedef_cursor, cursor_template, underlying_type)

    assert_includes rendered, "Rice::Data_Type<Tests::FunctionTemplate<&Tests::callback_ints>>"
    assert_includes rendered, "FunctionTemplate_instantiate<&Tests::callback_ints>"
  end

  def test_namespace_scope_forward_declared_classes_generate_placeholders_across_headers
    config_dir = File.join(__dir__, "headers", "cpp")
    config = load_config(config_dir)
    inputter = RubyBindgen::Inputter.new(config_dir, ["forward_declared_classes.hpp",
                                                      "forward_declared_all_layers.hpp"])
    outputter = create_outputter("cpp")
    generator = RubyBindgen::Generators::Rice.new(inputter, outputter, config)

    capture_io do
      generator.generate
    end

    classes_cpp = outputter.output_paths.fetch(outputter.output_path("forward_declared_classes-rb.cpp"))
    all_layers_cpp = outputter.output_paths.fetch(outputter.output_path("forward_declared_all_layers-rb.cpp"))

    assert_includes classes_cpp,
                    'define_class_under<ForwardDeclaredClasses::ActivationLayer>(rb_mForwardDeclaredClasses, "ActivationLayer")'
    assert_includes all_layers_cpp,
                    'define_class_under<ForwardDeclaredClasses::ActivationLayer, ForwardDeclaredClasses::Layer>(rb_mForwardDeclaredClasses, "ActivationLayer")'
  end

  def test_same_file_forward_declarations_only_render_the_complete_class
    parsed, = parse_cpp(<<~CPP)
      namespace Tests {
        class Forward;

        class Base {
        public:
          virtual ~Base() = default;
        };

        class Forward : public Base {
        public:
          int value() const { return 1; }
        };
      }
    CPP

    inputter = RubyBindgen::Inputter.new(parsed.dir, ["fixture.hpp"])
    outputter = create_outputter("cpp")
    config = load_config(File.join(__dir__, "headers", "cpp"))
    generator = RubyBindgen::Generators::Rice.new(inputter, outputter, config)

    capture_io { generator.generate }

    generated_cpp = outputter.output_paths.fetch(outputter.output_path("fixture-rb.cpp"))

    assert_equal 1, generated_cpp.scan('define_class_under<Tests::Forward, Tests::Base>(rb_mTests, "Forward")').size
    refute_includes generated_cpp, 'define_class_under<Tests::Forward>(rb_mTests, "Forward")'
  end

  def test_namespace_scope_opaque_types_with_project_definitions_are_generated
    config_dir = File.join(__dir__, "headers", "cpp")
    config = load_config(config_dir)
    inputter = RubyBindgen::Inputter.new(config_dir, ["opaque_namespace_api.hpp",
                                                      "opaque_namespace_full.hpp"])
    outputter = create_outputter("cpp")
    generator = RubyBindgen::Generators::Rice.new(inputter, outputter, config)

    capture_io { generator.generate }

    generated_cpp = outputter.output_paths.fetch(outputter.output_path("opaque_namespace_api-rb.cpp"))

    assert_includes generated_cpp, "Constructor<Tests::OpaqueNamespaceConsumer, const Tests::Render::Handle &>()"
    assert_includes generated_cpp, '"in_handle", &Tests::OpaqueNamespaceConsumer::inHandle'
    assert_includes generated_cpp, '"out_handle", &Tests::OpaqueNamespaceConsumer::outHandle'
    assert_includes generated_cpp, '"out_handle_ref", &Tests::OpaqueNamespaceConsumer::outHandleRef'
    assert_includes generated_cpp, '"set_handle", &Tests::OpaqueNamespaceConsumer::setHandle'
  end

  def test_namespace_scope_opaque_type_lookup_does_not_log_inputs_twice
    config_dir = File.join(__dir__, "headers", "cpp")
    config = load_config(config_dir)
    inputter = RubyBindgen::Inputter.new(config_dir, ["opaque_namespace_api.hpp",
                                                      "opaque_namespace_full.hpp"])
    outputter = create_outputter("cpp")
    generator = RubyBindgen::Generators::Rice.new(inputter, outputter, config)

    stdout, = capture_subprocess_io { generator.generate }

    assert_equal 1, stdout.scan(/opaque_namespace_api\.hpp/).size
    assert_equal 1, stdout.scan(/opaque_namespace_full\.hpp/).size
  end

  def test_out_of_class_nested_definitions_are_rendered_only_under_the_parent
    parsed, = parse_cpp(<<~CPP)
      namespace Tests {
        class Outer {
        public:
          class Inner;
          Inner value() const;
        };

        class Outer::Inner {
        public:
          static const int Flag = 1;
          int payload;
        };
      }
    CPP

    inputter = RubyBindgen::Inputter.new(parsed.dir, ["fixture.hpp"])
    outputter = create_outputter("cpp")
    config = load_config(File.join(__dir__, "headers", "cpp"))
    generator = RubyBindgen::Generators::Rice.new(inputter, outputter, config)

    capture_io { generator.generate }

    generated_cpp = outputter.output_paths.fetch(outputter.output_path("fixture-rb.cpp"))
    assert_equal 1, generated_cpp.scan('rb_cTestsOuterInner = define_class_under<Tests::Outer::Inner>').size
    assert_equal 1, generated_cpp.scan('define_method<Tests::Outer::Inner(Tests::Outer::*)() const>("value"').size
  end
end
