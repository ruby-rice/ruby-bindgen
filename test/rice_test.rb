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

  def test_enum
    header = "cpp/enum.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_function
    header = "cpp/function.hpp"
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
end
