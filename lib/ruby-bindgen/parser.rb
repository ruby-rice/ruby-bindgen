# frozen_string_literal: true

require 'pathname'

module RubyBindgen
  class Parser
    class ParseError < RuntimeError
      attr_reader :path, :details

      def initialize(path, details: [])
        @path = path
        @details = details
        super(build_message(path, details))
      end

      private

      def build_message(path, details)
        return "Failed to parse: #{path}" if details.empty?

        formatted_details = details.map { |detail| "  #{detail}" }.join("\n")
        "Parse errors in #{path}:\n#{formatted_details}"
      end
    end

    attr_reader :inputter, :clang_args

    def initialize(inputter, clang_args, libclang: nil)
      @inputter = inputter
      @clang_args = clang_args

      # Set libclang path before loading ffi-clang (it reads ENV on load)
      ENV['LIBCLANG'] = libclang if libclang

      # Lazy-load ffi-clang and its refinements so CMake format doesn't need libclang
      require 'ffi/clang'
      require 'ruby-bindgen/refinements/cursor'
      require 'ruby-bindgen/refinements/type'

      @index = FFI::Clang::Index.new(exclude_declarations_from_pch: false, display_diagnostics: true)
    end

    def generate(visitor)
      visitor.visit_start

      STDOUT << "\n" << "Processing:" << "\n"
      self.inputter.each do |path, relative_path|
        STDOUT << "  " << path << "\n"
        begin
          translation_unit = parse_translation_unit(path)
        rescue ParseError => error
          raise unless visitor.respond_to?(:visit_parse_error)

          visitor.visit_parse_error(path, relative_path, error)
          next
        end
        visitor.visit_translation_unit(translation_unit, path, relative_path)
      end

      visitor.visit_end
    end

    private

    def parse_translation_unit(path)
      translation_unit = @index.parse_translation_unit(path, self.clang_args, [],
                                                       [:detailed_preprocessing_record, :skip_function_bodies])

      raise ParseError.new(path) if translation_unit.nil?

      check_diagnostics(translation_unit, path)
      translation_unit
    end

    def check_diagnostics(translation_unit, path)
      errors = translation_unit.diagnostics.select { |d| d.severity == :fatal || d.severity == :error }
      return if errors.empty?

      details = errors.map { |d| "#{d.severity}: #{d.spelling}" }
      raise ParseError.new(path, details: details)
    end
  end
end
