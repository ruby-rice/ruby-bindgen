# frozen_string_literal: true

require 'fileutils'
require 'find'
require 'pathname'

module RubyBindgen
  class Outputter
    attr_reader :base_path, :output_paths

    def initialize(base_path)
      @base_path = base_path
      @output_paths = []
    end

    def output_path(relative_path)
      File.expand_path(File.join(self.base_path, relative_path))
    end

    def write(relative_path, content)
      path = self.output_path(relative_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "wb") do |file|
        file << cleanup_whitespace(content)
      end
      @output_paths << path
    end

    private

    # Clean up whitespace issues in generated content:
    # - Collapse multiple consecutive blank lines to single blank line
    # - Remove blank lines before closing braces
    def cleanup_whitespace(content)
      content = content.gsub(/\n{3,}/, "\n\n")
      content = content.gsub(/\n\n(\s*\})/, "\n\\1")
      content
    end
  end
end