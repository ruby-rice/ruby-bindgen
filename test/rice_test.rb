# encoding: UTF-8

require_relative './abstract_test'

class RiceTest < AbstractTest
  def test_class
    parser = parse_file('headers/cpp/class.hpp')
    visitor = RubyBindgen::Visitors::Rice.new(parser.translation_unit)
    io = visitor.visit
    validate_result('rice/class.hpp', io.string)
  end

  def test_enum
    parser = parse_file('headers/cpp/enum.hpp')
    visitor = RubyBindgen::Visitors::Rice.new(parser.translation_unit)
    io = visitor.visit
    validate_result('rice/enum.hpp', io.string)
  end

  def test_function
    parser = parse_file('headers/cpp/function.hpp')
    visitor = RubyBindgen::Visitors::Rice.new(parser.translation_unit)
    io = visitor.visit
    validate_result('rice/function.hpp', io.string)
  end

  def test_inheritance
    parser = parse_file('headers/cpp/inheritance.hpp')
    visitor = RubyBindgen::Visitors::Rice.new(parser.translation_unit)
    io = visitor.visit
    validate_result('rice/inheritance.hpp', io.string)
  end
end
