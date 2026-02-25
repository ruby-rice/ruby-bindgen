# frozen_string_literal: true

require 'find'
require 'pathname'

module RubyBindgen
  class Parser
    attr_reader :inputter, :clang_args

    def initialize(inputter, clang_args, libclang: nil)
      @inputter = inputter
      @clang_args = clang_args

      # Set libclang path before loading ffi-clang (it reads ENV on load)
      ENV['LIBCLANG'] = libclang if libclang

      # Lazy-load ffi-clang and its refinements so CMake format doesn't need libclang
      require 'ffi/clang'
      require 'ruby-bindgen/refinements/translation_unit'
      require 'ruby-bindgen/refinements/cursor'
      require 'ruby-bindgen/refinements/source_range'
      require 'ruby-bindgen/refinements/type'

      @index = FFI::Clang::Index.new(false, true)
    end

    def generate(visitor)
      visitor.visit_start

      STDOUT << "\n" << "Processing:" << "\n"
      self.inputter.each do |path, relative_path|
        STDOUT << "  " << path << "\n"
        translation_unit = @index.parse_translation_unit(path, self.clang_args, [],
                                                         [:detailed_preprocessing_record, :skip_function_bodies])

        visitor.visit_translation_unit(translation_unit, path, relative_path)
      end

      visitor.visit_end
    end
  end
end
