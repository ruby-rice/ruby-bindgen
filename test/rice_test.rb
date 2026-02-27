# encoding: UTF-8

require_relative './abstract_test'

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
                  skip_symbols: ["skippedByName", "alsoSkippedByName", "skippedMethod", "SkippedClass", "SkippedTemplateClass", "SkippedArgType"])
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
                    {"from" => "/^MatxInt(\\d+)$/", "to" => "Matx\\1i"}
                  ])
  end

  def test_cross_file_typedef
    # Tests that typedefs from included headers are found when generating
    # base classes. DerivedVector4d inherits from BaseMatrix<double, 4>,
    # which has typedef BaseMatrix4d in cross_file_base.hpp.
    run_rice_test(["cross_file_base.hpp", "cross_file_derived.hpp"])
  end
end
