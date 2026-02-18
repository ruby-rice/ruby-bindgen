require 'bundler/setup'
require 'minitest/autorun'
require 'yaml'

# Load platform-specific bindings config from a directory.
# Matches the production config format (see docs/configuration.md).
def load_bindings_config(config_dir)
  config_path = File.join(config_dir, 'bindings.yaml')
  return {} unless File.exist?(config_path)

  config = YAML.safe_load(File.read(config_path), permitted_classes: [], permitted_symbols: [], aliases: true)

  # Select toolchain: clang-cl for MSVC (mswin), clang for everything else (Linux/Mac/MinGW)
  toolchain = RUBY_PLATFORM =~ /mswin/ ? 'clang-cl' : 'clang'

  result = {}

  toolchain_config = config[toolchain]
  if toolchain_config.is_a?(Hash)
    result[:libclang] = toolchain_config['libclang'] if toolchain_config['libclang']
    if toolchain_config['args']
      result[:clang_args] = toolchain_config['args'].map do |arg|
        # Resolve relative -I paths relative to config directory (same as production resolve_path)
        arg.start_with?('-I') ? "-I#{File.expand_path(arg[2..], config_dir)}" : arg
      end
    end
  end

  result
end

# Set up libclang path from config
%w[cpp c c/clang-c].each do |dir|
  config = load_bindings_config(File.join(__dir__, 'headers', dir))
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
      config = load_bindings_config(config_dir)
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
