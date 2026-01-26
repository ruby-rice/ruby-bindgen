require 'bundler/setup'
require 'minitest/autorun'
require 'yaml'

# Load platform-specific bindings config
def load_bindings_config
  config_name = Gem.win_platform? ? 'bindings-windows.yaml' : 'bindings-linux.yaml'
  config_path = File.join(__dir__, 'headers', config_name)

  return {} unless File.exist?(config_path)

  config = YAML.safe_load(File.read(config_path), permitted_classes: [], permitted_symbols: [], aliases: true)
  config.transform_keys(&:to_sym)
end

# Set up libclang path from config
bindings_config = load_bindings_config
if bindings_config[:libclang]
  ENV["LIBCLANG"] = bindings_config[:libclang]
end

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
    # Load platform-specific clang args if not provided
    if args.nil?
      config = load_bindings_config
      args = config[:clang_args]
    end
    RubyBindgen::Parser.new(self.create_inputter(header), args)
  end

  def create_visitor(klass, header, project: nil, **options)
    klass.new(self.create_outputter(header), project, **options)
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

