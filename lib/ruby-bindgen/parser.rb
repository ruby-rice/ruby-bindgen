# frozen_string_literal: true

require 'find'
require 'pathname'

module RubyBindgen
  class Parser
    attr_reader :inputter, :clang_args

    def initialize(inputter, clang_args, follow_includes = false)
      @inputter = inputter
      @clang_args = clang_args
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