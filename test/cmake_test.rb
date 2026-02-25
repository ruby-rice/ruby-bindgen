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

  def test_cmake_without_project
    config_dir = File.join(__dir__, "headers", "cpp")
    config = load_config(config_dir, 'cmake.yaml')
    config[:project] = nil
    outputter = create_outputter("cpp")
    inputter = RubyBindgen::Inputter.new(outputter.base_path, ["**/*-rb.cpp"])
    generator = RubyBindgen::Generators::CMake.new(inputter, outputter, config)
    generator.generate

    output_files = generator.outputter.output_paths.keys
    assert output_files.none? { |f| f.end_with?("CMakePresets.json") },
           "CMakePresets.json should not be generated without project"

    root_cmake = generator.outputter.output_path("CMakeLists.txt")
    assert !output_files.include?(root_cmake),
           "Root CMakeLists.txt should not be generated without project"
  end
end
