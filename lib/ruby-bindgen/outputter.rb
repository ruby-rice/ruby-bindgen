# frozen_string_literal: true

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
        file << content
      end
      @output_paths << path
    end
  end
end