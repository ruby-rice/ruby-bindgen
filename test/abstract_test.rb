require 'bundler/setup'
require 'minitest/autorun'

ENV["LIBCLANG"]="C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/Llvm/x64/bin/libclang.dll"

# Add refinements directory to load path to make it easier to test locally built extensions
ext_path = File.expand_path(File.join(__dir__, '..', 'lib'))
$LOAD_PATH.unshift(File.expand_path(ext_path))

require 'ruby-bindgen'

class AbstractTest < Minitest::Test
  def parse_file(header, args = nil)
    path = File.join(__dir__, header)
    RubyBindgen::Parser.new(path, args)
  end

  def validate_result(expected_path, generated)
    expected_path = File.join(__dir__, expected_path)

    File.open(expected_path, 'wb') do |file|
      file << generated
    end

    expected = File.read(expected_path, mode: 'rb')
    assert_equal(expected, generated)
  end
end

