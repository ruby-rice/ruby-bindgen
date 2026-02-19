# encoding: UTF-8

require_relative './abstract_test'

class CMakeTest < AbstractTest
  def test_cmake
    header = "cpp/classes.hpp"
    config_dir = File.join(__dir__, "headers", "cpp")
    config = load_config(config_dir, 'bindings_cmake.yaml')
    outputter = create_outputter(header)
    visitor = RubyBindgen::Visitors::CMake.new(outputter, config)
    visitor.visit_start
    validate_result(visitor.outputter)
  end
end
