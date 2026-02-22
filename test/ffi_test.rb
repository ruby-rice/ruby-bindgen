# encoding: UTF-8

require_relative './abstract_test'

class FfiTest < AbstractTest
  def test_forward_declarations
    run_ffi_test("forward.h", library_names: ["forward"], library_versions: [])
  end

  def test_structs
    run_ffi_test("structs.h", library_names: ["structs"], library_versions: [])
  end

  def test_clang
    run_ffi_test("clang-c/index.h", library_names: ["clang"], library_versions: [])
  end

  def test_proj
    run_ffi_test("proj.h", library_names: ["proj"], library_versions: [])
  end

  def test_sqlite3
    run_ffi_test("sqlite3.h", library_names: ["sqlite3"], library_versions: [])
  end

  def test_filtering
    run_ffi_test("filtering.h",
      library_names: ["filtering"], library_versions: [],
      skip_symbols: ["skippedFunction", "alsoSkipped", "/internal_helper.*/", "SkippedStruct", "SkippedEnum", "SkippedTypedef"])
  end

  private

  def run_ffi_test(match, **overrides)
    config_dir = File.join(__dir__, "headers", "c")
    config = load_config(config_dir)
    config[:match] = Array(match)
    overrides.each { |key, value| config[key] = value }

    inputter = RubyBindgen::Inputter.new(config_dir, config[:match])
    parser = RubyBindgen::Parser.new(inputter, config[:clang_args] || [])
    outputter = create_outputter("c")
    visitor = RubyBindgen::Visitors::FFI.new(outputter, config)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end
end
