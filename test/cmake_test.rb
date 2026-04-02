# encoding: UTF-8

require 'fileutils'

require_relative './abstract_test'

class CMakeTest < AbstractTest
  def test_cmake
    config_dir = File.join(__dir__, "headers", "cpp")
    config = load_config(config_dir, 'cmake.yaml')
    outputter = create_outputter("cpp")
    inputter = RubyBindgen::Inputter.new(outputter.base_path, config[:match] || ["**/*-rb.cpp"], config[:skip] || [])
    generator = RubyBindgen::Generators::CMake.new(inputter, outputter, config)
    generator.generate
    generated_root_cmake = generator.outputter.output_paths.fetch(generator.outputter.output_path("CMakeLists.txt"))
    assert_includes generated_root_cmake, '"${CMAKE_CURRENT_SOURCE_DIR}/../../headers/cpp/system"'
    validate_result(generator.outputter)
  end

  def test_cmake_without_project
    config_dir = File.join(__dir__, "headers", "cpp")
    config = load_config(config_dir, 'cmake.yaml')
    config[:project] = nil
    outputter = create_outputter("cpp")
    inputter = RubyBindgen::Inputter.new(outputter.base_path, config[:match] || ["**/*-rb.cpp"], config[:skip] || [])
    generator = RubyBindgen::Generators::CMake.new(inputter, outputter, config)
    generator.generate

    output_files = generator.outputter.output_paths.keys
    no_presets = output_files.none? do |path|
      path.end_with?("CMakePresets.json")
    end
    assert no_presets,
           "CMakePresets.json should not be generated without project"

    root_cmake = generator.outputter.output_path("CMakeLists.txt")
    assert !output_files.include?(root_cmake),
           "Root CMakeLists.txt should not be generated without project"

    assert_equal [generator.outputter.output_path("guards/CMakeLists.txt"),
                  generator.outputter.output_path("guards/dnn/CMakeLists.txt")].sort,
                 output_files.sort,
                 "Only subdirectory CMakeLists.txt files should be generated without project"
  end

  def test_cmake_overlapping_guards_raise
    require 'tmpdir'
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "guards"))
      File.write(File.join(dir, "guards", "cudaarithm-rb.cpp"), "")

      config_dir = File.join(__dir__, "headers", "cpp")
      config = load_config(config_dir, 'cmake.yaml')
      config[:guards] = {
        "TEST_HAS_CUDA" => ["guards/cuda*-rb.cpp"],
        "TARGET Test::cuda" => ["guards/cudaarithm-rb.cpp"]
      }

      outputter = RubyBindgen::TestOutputter.new(dir)
      inputter = RubyBindgen::Inputter.new(dir, ["**/*-rb.cpp"])
      generator = RubyBindgen::Generators::CMake.new(inputter, outputter, config)

      error = assert_raises(ArgumentError) { generator.generate }
      assert_match(/matched multiple guard conditions/, error.message)
    end
  end
end
