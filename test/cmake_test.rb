# encoding: UTF-8

require_relative './abstract_test'

class CMakeTest < AbstractTest
  def test_cmake
    header = "cpp/class.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::CMake, "test-class", header)
    parser.generate(visitor)
  end
end
