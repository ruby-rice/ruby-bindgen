require 'bundler/setup'
require 'minitest/autorun'

ENV["LIBCLANG"]="C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/Llvm/x64/bin/libclang.dll"

# Add refinements directory to load path to make it easier to test locally built extensions
ext_path = File.expand_path(File.join(__dir__, '..', 'lib'))
$LOAD_PATH.unshift(File.expand_path(ext_path))

require 'ruby-bindgen'

class AbstractTest < Minitest::Test
  def create_inputter(header)
    input_path = File.join(__dir__, "headers", File.dirname(header))
    RubyBindgen::Inputter.new(input_path, File.basename(header))
  end

  def create_outputter(header)
    output_path = File.join(__dir__, "bindings", File.dirname(header))
    RubyBindgen::Outputter.new(output_path)
  end

  def create_parser(header, args = nil)
    RubyBindgen::Parser.new(self.create_inputter(header), args)
  end

  def create_visitor(klass, project, header)
    klass.new(project, self.create_outputter(header))
  end

  def parse(header, args = nil)
    parser = create_parser(header, args)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, "unit-test", header)
    parser.generate(visitor)
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

