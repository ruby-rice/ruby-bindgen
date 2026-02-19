require 'yaml'
require 'pathname'

module RubyBindgen
  class Config
    def initialize(config_path)
      @config_dir = File.dirname(File.expand_path(config_path))
      raw = YAML.safe_load(File.read(config_path), permitted_classes: [], permitted_symbols: [], aliases: true)
      @data = symbolize_keys(raw)
      resolve_toolchain
      resolve_paths
    end

    def [](key)
      @data[key]
    end

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
      hash.transform_keys(&:to_sym).transform_values do |value|
        case value
        when Hash then symbolize_keys(value)
        else value
        end
      end
    end
  end
end
