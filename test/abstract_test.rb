require 'bundler/setup'
require 'minitest/autorun'

require 'ruby-bindgen/config'

# Set up libclang path from config
%w[cpp c c/clang-c].each do |dir|
  config = RubyBindgen::Config.new(File.join(__dir__, 'headers', dir, 'bindings.yaml'))
  if config[:libclang]
    ENV["LIBCLANG"] = config[:libclang]
    break
  end
end

# Add refinements directory to load path to make it easier to test locally built extensions
ext_path = File.expand_path(File.join(__dir__, '..', 'lib'))
$LOAD_PATH.unshift(File.expand_path(ext_path))

require 'ruby-bindgen'
require_relative './test_outputter'

class AbstractTest < Minitest::Test
  def load_config(config_dir, config_file = 'bindings.yaml')
    RubyBindgen::Config.new(File.join(config_dir, config_file))
  end

  def create_inputter(header)
    input_path = File.join(__dir__, "headers", File.dirname(header))
    RubyBindgen::Inputter.new(input_path, File.basename(header))
  end

  def create_outputter(header)
    output_path = File.join(__dir__, "bindings", File.dirname(header))
    RubyBindgen::TestOutputter.new(output_path)
  end

  def create_parser(header, args = nil)
    if args.nil?
      config_dir = File.join(__dir__, "headers", File.dirname(header))
      config = load_config(config_dir)
      args = config[:clang_args]
    end
    RubyBindgen::Parser.new(self.create_inputter(header), args)
  end

  def create_visitor(klass, header, config = nil, **overrides)
    config_dir = File.join(__dir__, "headers", File.dirname(header))
    config ||= load_config(config_dir)
    overrides.each { |key, value| config[key] = value }
    klass.new(self.create_outputter(header), config)
  end

  def validate_result(outputter)
    outputter.output_paths.each do |path, content|
      if ENV["UPDATE_EXPECTED"]
        File.open(path, 'wb') do |file|
          file << content
        end
      else
        expected = File.read(path, mode: "rb")
        assert_equal(expected, content, "Mismatch in #{path}")
      end
    end
  end
end
