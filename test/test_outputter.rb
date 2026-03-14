# frozen_string_literal: true

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
      @output_paths[self.output_path(relative_path)] = cleanup_whitespace(content)
    end

    private

    # Match production Outputter's whitespace cleanup so golden files
    # reflect what production actually writes to disk.
    def cleanup_whitespace(content)
      content = content.gsub(/\n{3,}/, "\n\n")
      content = content.gsub(/\n\n(\s*\})/, "\n\\1")
      content
    end
  end
end