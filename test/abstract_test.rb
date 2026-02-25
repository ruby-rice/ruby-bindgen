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

  def create_outputter(subdir)
    output_path = File.join(__dir__, "bindings", subdir)
    RubyBindgen::TestOutputter.new(output_path)
  end

  def run_rice_test(match, **overrides)
    config_dir = File.join(__dir__, "headers", "cpp")
    config = load_config(config_dir)
    config[:match] = Array(match)
    overrides.each { |key, value| config[key] = value }

    inputter = RubyBindgen::Inputter.new(config_dir, config[:match])
    outputter = create_outputter("cpp")
    generator = RubyBindgen::Generators::Rice.new(inputter, outputter, config)
    generator.generate
    validate_result(generator.outputter)
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
