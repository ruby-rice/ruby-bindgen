# encoding: UTF-8

require_relative './abstract_test'

class CMakeTest < AbstractTest
  def test_cmake
    header = "cpp/classes.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::CMake, header, project: "test_project",
                             include_dirs: ["${CMAKE_CURRENT_SOURCE_DIR}/../../headers/cpp"])
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end
end
