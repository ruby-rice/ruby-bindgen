# encoding: UTF-8

require_relative './abstract_test'

class RiceTest < AbstractTest
  def test_classes
    header = "cpp/classes.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_enums
    header = "cpp/enums.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_functions
    header = "cpp/functions.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_inheritance
    header = "cpp/inheritance.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_template
    header = "cpp/templates.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_constructors
    header = "cpp/constructors.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_operators
    header = "cpp/operators.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_default_values
    header = "cpp/default_values.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_iterators
    header = "cpp/iterators.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_template_inheritance
    header = "cpp/template_inheritance.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_overloads
    header = "cpp/overloads.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_incomplete_types
    header = "cpp/incomplete_types.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_filtering
    header = "cpp/filtering.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header, nil,
                             export_macros: ["MY_EXPORT"],
                             skip_symbols: ["skippedByName", "alsoSkippedByName", "skippedMethod", "SkippedClass", "SkippedTemplateClass", "SkippedArgType"])
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_buffers
    header = "cpp/buffers.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_template_defaults
    header = "cpp/template_defaults.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_cross_file_typedef
    # Tests that typedefs from included headers are found when generating
    # base classes. DerivedVector4d inherits from BaseMatrix<double, 4>,
    # which has typedef BaseMatrix4d in cross_file_base.hpp.
    header = "cpp/cross_file_derived.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end
end
