require 'bundler/setup'
require 'minitest/autorun'

ENV["LIBCLANG"]="C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/Llvm/x64/bin/libclang.dll"

# Add refinements directory to load path to make it easier to test locally built extensions
ext_path = File.expand_path(File.join(__dir__, '..', 'lib'))
$LOAD_PATH.unshift(File.expand_path(ext_path))

require 'ruby-bindgen'
require_relative './test_outputter'

class AbstractTest < Minitest::Test
  def create_inputter(header)
    input_path = File.join(__dir__, "headers", File.dirname(header))
    RubyBindgen::Inputter.new(input_path, File.basename(header))
  end

  def create_outputter(header)
    output_path = File.join(__dir__, "bindings", File.dirname(header))
    RubyBindgen::TestOutputter.new(output_path)
  end

  def create_parser(header, args = nil)
    RubyBindgen::Parser.new(self.create_inputter(header), args)
  end

  def create_visitor(klass, project, header, **options)
    klass.new(project, self.create_outputter(header), **options)
  end

  def validate_result(outputter)
    outputter.output_paths.each do |path, content|
      File.open(path, 'wb') do |file|
        file << content
      end
      actual = File.read(path, mode: "rb")
      assert_equal(content, actual)
    end
  end
end

