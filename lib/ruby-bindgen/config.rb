require 'yaml'
require 'pathname'

module RubyBindgen
  class Config
    def initialize(config_path)
      @config_dir = File.dirname(File.expand_path(config_path))
      raw = YAML.safe_load(File.read(config_path), permitted_classes: [], permitted_symbols: [], aliases: true)
      # YAML.safe_load returns nil for an empty file. Treat that as an empty
      # config so the CLI's validate_config can produce its useful "Config
      # must specify 'output'" message instead of a NoMethodError.
      @data = raw.is_a?(Hash) ? symbolize_keys(raw) : {}
      resolve_toolchain
      resolve_paths
    end

    def [](key)
      @data[key]
    end

    # @api private
    # Used by tests for ad-hoc overrides and by the CLI to default :input to
    # :output. Not intended for downstream code; the public contract is read-only.
    def []=(key, value)
      @data[key] = value
    end

    private

    def resolve_toolchain
      toolchain = RUBY_PLATFORM =~ /mswin/ ? :'clang-cl' : :clang

      toolchain_config = @data[toolchain]
      if toolchain_config.is_a?(Hash)
        @data[:libclang] = toolchain_config[:libclang]
        @data[:clang_args] = toolchain_config[:args]&.map do |arg|
          # Resolve relative -I paths relative to config directory
          arg.start_with?('-I') ? "-I#{File.expand_path(arg[2..], @config_dir)}" : arg
        end
      end
    end

    def resolve_paths
      @data[:input] = resolve_path(@data[:input]) if @data[:input]
      @data[:output] = resolve_path(@data[:output]) if @data[:output]
    end

    def resolve_path(path)
      return path if Pathname.new(path).absolute?
      File.expand_path(path, @config_dir)
    end

    def symbolize_keys(hash)
      hash.transform_keys { |k| k.is_a?(String) ? k.to_sym : k }.transform_values do |value|
        case value
        when Hash then symbolize_keys(value)
        when Array then value.map { |v| v.is_a?(Hash) ? symbolize_keys(v) : v }
        else value
        end
      end
    end
  end
end
