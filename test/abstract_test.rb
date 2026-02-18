require 'bundler/setup'
require 'minitest/autorun'
require 'yaml'

# Load platform-specific bindings config
def load_bindings_config
  config_path = File.join(__dir__, 'headers', 'bindings.yaml')
  return {} unless File.exist?(config_path)

  config = YAML.safe_load(File.read(config_path), permitted_classes: [], permitted_symbols: [], aliases: true)

  # Select toolchain: clang-cl for MSVC (mswin), clang for everything else (Linux/Mac/MinGW)
  toolchain = RUBY_PLATFORM =~ /mswin/ ? 'clang-cl' : 'clang'

  result = {}

  # Extract libclang path for this toolchain
  if config['libclang']&.is_a?(Hash) && config['libclang'][toolchain]
    result[:libclang] = config['libclang'][toolchain]
  elsif config['libclang']&.is_a?(String)
    result[:libclang] = config['libclang']
  end

  # Extract clang_args for this toolchain
  if config['clang_args']&.is_a?(Hash) && config['clang_args'][toolchain]
    result[:clang_args] = config['clang_args'][toolchain]
  elsif config['clang_args']&.is_a?(Array)
    result[:clang_args] = config['clang_args']
  end

  result
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
    # Add test headers root to include path so relative includes work
    # e.g., for "c/clang-c/index.h", add test/headers/c so #include "clang-c/BuildSystem.h" resolves
    headers_root = File.join(__dir__, "headers", header.split('/').first)
    args = Array(args) + ["-I#{headers_root}"]
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

