# encoding: UTF-8

require_relative './abstract_test'
require_relative './type_index_test'
require_relative './reference_qualifier_test'
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
    run_rice_test("template_inheritance.hpp")
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
      File.write(File.join(dir, "broken.hpp"), "class Broken { int x }")

      config = load_config(File.join(__dir__, "headers", "cpp"))
      config[:match] = ["broken.hpp"]

      inputter = RubyBindgen::Inputter.new(dir, config[:match])
      outputter = create_outputter("cpp")
      generator = RubyBindgen::Generators::Rice.new(inputter, outputter, config)

      error = assert_raises(RuntimeError) { generator.generate }
      assert_match(/Parse errors in/, error.message)
    end
  end
end
