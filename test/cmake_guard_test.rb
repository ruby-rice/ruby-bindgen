# encoding: UTF-8

require_relative './abstract_test'
require 'tmpdir'

class CMakeGuardTest < Minitest::Test
  def test_matches_files_and_directories
    base = File.join(Dir.tmpdir, "project")

    guard = RubyBindgen::Generators::CMake::Guard.new(
      condition: "TEST_HAS_CUDA",
      patterns: ["guards/cuda*-rb.cpp", "guards/dnn"],
      base_path: base
    )

    match = guard.match(
      file_paths: [File.join(base, "guards/base-rb.cpp"),
                   File.join(base, "guards/cudaarithm-rb.cpp"),
                   File.join(base, "guards/cudaimgproc-rb.cpp")],
      directory_paths: [File.join(base, "guards"),
                        File.join(base, "guards/dnn")]
    )

    assert_equal "TEST_HAS_CUDA", match.condition
    assert_equal [File.join(base, "guards/dnn")], match.directories
    assert_equal [File.join(base, "guards/cudaarithm-rb.cpp"),
                  File.join(base, "guards/cudaimgproc-rb.cpp")], match.files
  end

  def test_warns_for_unmatched_patterns
    base = File.join(Dir.tmpdir, "project")

    guard = RubyBindgen::Generators::CMake::Guard.new(
      condition: "TARGET Test::missing",
      patterns: ["guards/missing"],
      base_path: base
    )

    _stdout, stderr = capture_io do
      match = guard.match(file_paths: [], directory_paths: [])

      assert_equal "TARGET Test::missing", match.condition
      assert_empty match.directories
      assert_empty match.files
    end

    assert_match(/did not match any generated paths/, stderr)
  end
end
