# encoding: UTF-8

require_relative './abstract_test'

class CMakeTest < AbstractTest
  def test_cmake
    config_dir = File.join(__dir__, "headers", "cpp")
    config = load_config(config_dir, 'cmake.yaml')
    outputter = create_outputter("cpp")
    inputter = RubyBindgen::Inputter.new(outputter.base_path, ["**/*-rb.cpp"])
    generator = RubyBindgen::Generators::CMake.new(inputter, outputter, config)
    generator.generate
    validate_result(generator.outputter)
  end
end
