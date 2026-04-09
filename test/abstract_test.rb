require 'bundler/setup'
require 'fileutils'
require 'minitest/autorun'
Minitest.load_plugins

require 'ruby-bindgen/config'

if ENV['COVERAGE']
  require 'simplecov'
  if ENV['CI']
    require 'simplecov-cobertura'
    SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
  end
  SimpleCov.start do
    add_filter '/test/'
    track_files 'lib/**/*.rb'
  end
end

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

  def run_rice_test(match, **overrides, &block)
    config_dir = File.join(__dir__, "headers", "cpp")
    config = load_config(config_dir)
    config[:match] = Array(match)
    overrides.each { |key, value| config[key] = value }

    inputter = RubyBindgen::Inputter.new(config_dir, config[:match])
    outputter = create_outputter("cpp")
    generator = RubyBindgen::Generators::Rice.new(inputter, outputter, config)
    generator.generate
    validate_result(generator.outputter, &block)
  end

  def validate_result(outputter)
    generated_paths = Set.new

    outputter.output_paths.each do |path, content|
      generated_paths << path
      content = yield(content) if block_given?
      if ENV["UPDATE_EXPECTED"]
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, 'wb') do |file|
          file << content
        end
      else
        expected = File.read(path, mode: "rb")
        assert_equal(expected, content, "Mismatch in #{path}")
      end
    end

    # Detect stale expected files that were not generated this run.
    # Group generated files by base name prefix (e.g., "classes-rb") and check
    # for extra files on disk with the same prefix.
    prefixes = generated_paths.map { |p| File.basename(p).sub(/\.(cpp|hpp|ipp|rb)$/, '') }.uniq
    prefixes.each do |prefix|
      dir = File.dirname(generated_paths.first)
      Dir.glob(File.join(dir, "#{prefix}.*")).each do |existing|
        next if generated_paths.include?(existing)
        if ENV["UPDATE_EXPECTED"]
          File.delete(existing)
          $stderr.puts "Deleted stale expected file: #{existing}"
        else
          flunk "Stale expected file not generated: #{existing}"
        end
      end
    end
  end
end
