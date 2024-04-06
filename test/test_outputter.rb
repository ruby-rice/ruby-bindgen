# frozen_string_literal: true

require 'find'
require 'pathname'
require 'stringio'

module RubyBindgen
  class TestOutputter
    attr_reader :base_path, :output_paths

    def initialize(base_path)
      @base_path = base_path
      @output_paths = Hash.new
    end

    def output_path(relative_path)
      File.expand_path(File.join(self.base_path, relative_path))
    end

    def write(relative_path, content)
      @output_paths[self.output_path(relative_path)] = content
    end
  end
end