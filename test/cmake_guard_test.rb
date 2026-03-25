# encoding: UTF-8

require_relative './abstract_test'

class CMakeGuardTest < Minitest::Test
  def test_matches_files_and_directories
    guard = RubyBindgen::Generators::CMake::Guard.new(
      condition: "TEST_HAS_CUDA",
      patterns: ["guards/cuda*-rb.cpp", "guards/dnn"],
      base_path: "/tmp/project"
    )

    match = guard.match(
      file_paths: ["/tmp/project/guards/base-rb.cpp",
                   "/tmp/project/guards/cudaarithm-rb.cpp",
                   "/tmp/project/guards/cudaimgproc-rb.cpp"],
      directory_paths: ["/tmp/project/guards",
                        "/tmp/project/guards/dnn"]
    )

    assert_equal "TEST_HAS_CUDA", match.condition
    assert_equal ["/tmp/project/guards/dnn"], match.directories
    assert_equal ["/tmp/project/guards/cudaarithm-rb.cpp",
                  "/tmp/project/guards/cudaimgproc-rb.cpp"], match.files
  end

  def test_warns_for_unmatched_patterns
    guard = RubyBindgen::Generators::CMake::Guard.new(
      condition: "TARGET Test::missing",
      patterns: ["guards/missing"],
      base_path: "/tmp/project"
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
