# encoding: UTF-8

require_relative './abstract_test'
require_relative './namer_test'
require_relative './type_index_test'
require_relative './reference_qualifier_test'
require_relative './rice_generator_test'
require_relative './symbols_test'
require_relative './type_speller_test'
require_relative './template_resolver_test'
require_relative './signature_builder_test'

class RiceTest < AbstractTest
  def test_classes
    run_rice_test("classes.hpp")
  end

  def test_enums
    run_rice_test("enums.hpp")
  end

  def test_functions
    run_rice_test("functions.hpp")
  end

  def test_inheritance
    run_rice_test("inheritance.hpp")
  end

  def test_template
    run_rice_test("templates.hpp")
  end

  def test_constructors
    run_rice_test("constructors.hpp")
  end

  def test_operators
    run_rice_test("operators.hpp")
  end

  def test_default_values
    run_rice_test("default_values.hpp")
  end

  def test_iterators
    run_rice_test("iterators.hpp")
  end

  # STL container iterators (std::vector, std::map) whose fully_qualified_name
  # expands default template args on LLVM 21+. The compat shim cannot expand
  # defaults, so this test only runs on LLVM 21+.
  def test_iterators_stl
    require 'ffi/clang'
    skip "Requires LLVM 21+ for default template arg expansion" if FFI::Clang.clang_version < Gem::Version.new("21.0.0")
    run_rice_test("iterators_stl.hpp")
  end

  def test_template_inheritance
    run_rice_test("template_inheritance.hpp",
                  symbols: { skip: ["HiddenDerivediImpl"] })
  end

  def test_overloads
    run_rice_test("overloads.hpp")
  end

  def test_incomplete_types
    run_rice_test("incomplete_types.hpp")
  end

  def test_filtering
    run_rice_test("filtering.hpp",
                  export_macros: ["MY_EXPORT"],
                  symbols: { skip: ["skippedByName",
                                     "alsoSkippedByName",
                                     "skippedMethod",
                                     "SkippedClass",
                                     "SkippedTemplateClass",
                                     "SkippedArgType",
                                     "SkippedEnum",
                                     "SkippedUnion",
                                     "skippedVariable",
                                     "Outer::MyClass::overloaded(int, const int*)",
                                     "Outer::GuardedClass::GuardedClass(const int*)",
                                     "Outer::ConstructorWithNsParam::ConstructorWithNsParam(const Outer::MyParam*)",
                                     "Outer::takeAlias(Outer::MyParamAlias)",
                                     "Outer::takeValue<7>()",
                                     "Outer::DataType<Outer::Vec<float, 3>>",
                                     "Outer::DataType<double>::DataType(const double*)",
                                     "operator float",
                                     "/_dummy_enum_finalizer/",
                                     "_skipped_field"] })
  end

  def test_buffers
    run_rice_test("buffers.hpp")
  end

  def test_template_defaults
    run_rice_test("template_defaults.hpp")
  end

  def test_inline_namespaces
    run_rice_test("inline_namespaces.hpp")
  end

  def test_nested_class_templates
    run_rice_test("nested_class_templates.hpp")
  end

  def test_cmake_guards
    run_rice_test(["guards/base.hpp",
                   "guards/cudaarithm.hpp",
                   "guards/cudaimgproc.hpp",
                   "guards/dnn/layer.hpp"])
  end

  def test_mappings
    run_rice_test("mappings.hpp",
                  symbols: {
                    rename_methods: [
                      {"from" => "cv::VideoCapture::grab", "to" => "grab"},
                      {"from" => "cv::MatSize::operator()", "to" => "to_size"},
                      {"from" => "cv::Mat::operator()", "to" => "[]"},
                      {"from" => "cv::UMat::operator()", "to" => "[]"},
                      {"from" => "cv::Matx::operator()", "to" => "[]"}
                    ],
                    rename_types: [
                      {"from" => "/^MatxUChar(\\d+)$/", "to" => "Matx\\1b"},
                      {"from" => "/^MatxShort(\\d+)$/", "to" => "Matx\\1s"},
                      {"from" => "/^MatxInt(\\d+)$/", "to" => "Matx\\1i"},
                      {"from" => "RNG_MT19937", "to" => "RNG_MT19937"}
                    ]
                  })
  end

  def test_version_guards
    run_rice_test("version_guards.hpp",
                  version_check: "TEST_VERSION",
                  symbols: { skip: ["SKIPPED_MACRO"],
                             versions: {
                    20000 => ["Guards::MyClass::newMethod",
                              "Guards::MyClass::NEW_CONST",
                              "Guards::MyClass::overloaded(int, bool)",
                              "Guards::MyClass::MyClass(int, bool)",
                              "Guards::NEW_FLAG",
                              "Guards::newFunction",
                              "Guards::HalfFloat",
                              "Guards::DataType<Guards::HalfFloat>",
                              "/Guards::saturate_cast<Guards::HalfFloat>/"] } })
  end

  def test_unions
    run_rice_test("unions.hpp")
  end

  def test_project
    config_dir = File.join(__dir__, "headers", "cpp")
    config = load_config(config_dir)
    config[:match] = ["unions.hpp"]
    config[:project] = "myproject"

    inputter = RubyBindgen::Inputter.new(config_dir, config[:match])
    outputter = create_outputter("cpp_project")
    generator = RubyBindgen::Generators::Rice.new(inputter, outputter, config)
    generator.generate
    validate_result(generator.outputter)
  end

  def test_cross_file_typedef
    # Tests that typedefs from included headers are found when generating
    # base classes. DerivedVector4d inherits from BaseMatrix<double, 4>,
    # which has typedef BaseMatrix4d in cross_file_base.hpp.
    run_rice_test(["cross_file_base.hpp", "cross_file_derived.hpp"])
  end

  def test_parse_errors_raise
    require 'tmpdir'
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "broken.hpp"), "#include <missing_cuda_dependency.hpp>\n")

      config = load_config(File.join(__dir__, "headers", "cpp"))
      inputter = RubyBindgen::Inputter.new(dir, config[:match])
      visitor = Object.new
      visitor.define_singleton_method(:visit_start) {}
      visitor.define_singleton_method(:visit_translation_unit) { |_translation_unit, _path, _relative_path| }
      visitor.define_singleton_method(:visit_end) {}
      parser = RubyBindgen::Parser.new(inputter, config[:clang_args], libclang: config[:libclang])

      error = assert_raises(RubyBindgen::Parser::ParseError) do
        capture_io { parser.generate(visitor) }
      end
      assert_match(/Parse errors in/, error.message)
    end
  end

  def test_parse_errors_warn_and_continue
    config_dir = File.join(__dir__, "headers", "cpp")
    config = load_config(config_dir)
    config[:match] = ["classes.hpp", "parse_error_continue_broken.hpp"]

    inputter = RubyBindgen::Inputter.new(config_dir, config[:match])
    outputter = create_outputter("cpp")
    generator = RubyBindgen::Generators::Rice.new(inputter, outputter, config)

    _stdout, stderr = capture_io { generator.generate }

    assert_match(/Warning: skipping parse_error_continue_broken\.hpp because it could not be parsed/, stderr)
    assert_match(/Parse errors in .*parse_error_continue_broken\.hpp/, stderr)

    assert outputter.output_paths.key?(outputter.output_path("classes-rb.cpp"))
    assert outputter.output_paths.key?(outputter.output_path("classes-rb.hpp"))
    refute outputter.output_paths.key?(outputter.output_path("parse_error_continue_broken-rb.cpp"))
    refute outputter.output_paths.key?(outputter.output_path("parse_error_continue_broken-rb.hpp"))
    refute File.exist?(outputter.output_path("parse_error_continue_broken-rb.cpp"))
    refute File.exist?(outputter.output_path("parse_error_continue_broken-rb.hpp"))

    validate_result(outputter)
  end

  def test_template_partial_specializations
    config_dir = File.join(__dir__, "headers", "cpp")
    config = load_config(config_dir)
    config[:match] = ["template_partial_specializations.hpp"]

    inputter = RubyBindgen::Inputter.new(config_dir, config[:match])
    outputter = create_outputter("cpp")
    generator = RubyBindgen::Generators::Rice.new(inputter, outputter, config)

    capture_io { generator.generate }

    generated_cpp = outputter.output_paths.fetch(outputter.output_path("template_partial_specializations-rb.cpp"))
    generated_ipp = outputter.output_paths.fetch(outputter.output_path("template_partial_specializations-rb.ipp"))

    refute_includes generated_ipp, "call_and_postprocess_instantiate"
    refute_includes generated_cpp, "get_in_instantiate<Tests::Array<Tests::Mat>>"
    refute_includes generated_cpp, "get_out_instantiate<Tests::Array<Tests::Mat>>"
    assert_includes generated_ipp, "&Tests::KernelImpl<Impl, K>::backend"
    refute_includes generated_ipp, "&Tests::KernelImpl<Tests::FileStorage::Impl, K>::backend"

    expected_cpp = outputter.output_path("template_partial_specializations-rb.cpp")
    if ENV["UPDATE_EXPECTED"] || File.exist?(expected_cpp)
      validate_result(outputter)
    end
  end
end
