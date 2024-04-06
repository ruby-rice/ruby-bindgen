# encoding: UTF-8

require_relative './abstract_test'

class RiceTest < AbstractTest
  def test_class
    header = "cpp/class.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, "test-class", header)
    parser.generate(visitor)
  end

  def test_enum
    content = parse('cpp/enum.hpp')
    #validate_result('rice/enum.hpp', io.string)
  end

  def test_function
    content = parse('cpp/function.hpp')
    #validate_result('rice/function.hpp', io.string)
  end

  def test_inheritance
    content = parse('cpp/inheritance.hpp')
    #validate_result('rice/inheritance.hpp', io.string)
  end

  def test_template
    parse('cpp/templates.hpp')
  end

  def test_constructors
    parse('cpp/constructors.hpp')
  end
end
