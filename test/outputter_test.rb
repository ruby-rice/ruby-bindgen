# encoding: UTF-8

require_relative './abstract_test'
require 'tmpdir'

class OutputterTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("outputter-test")
    @outputter = RubyBindgen::Outputter.new(@dir)
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir && Dir.exist?(@dir)
  end

  def test_output_path
    assert_equal File.join(@dir, "foo.cpp"), @outputter.output_path("foo.cpp")
  end

  def test_output_path_with_subdirectory
    assert_equal File.join(@dir, "guards", "dnn", "layer-rb.cpp"),
                 @outputter.output_path("guards/dnn/layer-rb.cpp")
  end

  def test_write_creates_file
    @outputter.write("test.cpp", "hello")
    path = File.join(@dir, "test.cpp")
    assert File.exist?(path)
    assert_equal "hello", File.read(path, mode: "rb")
  end

  def test_write_creates_subdirectories
    @outputter.write("a/b/c.cpp", "nested")
    path = File.join(@dir, "a", "b", "c.cpp")
    assert File.exist?(path)
    assert_equal "nested", File.read(path, mode: "rb")
  end

  def test_write_tracks_output_paths
    @outputter.write("one.cpp", "first")
    @outputter.write("two.cpp", "second")
    assert_equal 2, @outputter.output_paths.size
    assert_equal "first", @outputter.output_paths[File.join(@dir, "one.cpp")]
    assert_equal "second", @outputter.output_paths[File.join(@dir, "two.cpp")]
  end

  def test_collapses_multiple_blank_lines
    @outputter.write("test.cpp", "a\n\n\n\nb")
    assert_equal "a\n\nb", File.read(File.join(@dir, "test.cpp"), mode: "rb")
  end

  def test_removes_blank_line_before_closing_brace
    @outputter.write("test.cpp", "{\n  x;\n\n}")
    assert_equal "{\n  x;\n}", File.read(File.join(@dir, "test.cpp"), mode: "rb")
  end
end
