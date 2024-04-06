# frozen_string_literal: true

require 'find'
require 'pathname'

module RubyBindgen
  class Outputter
    attr_reader :base_path

    def initialize(base_path)
      @base_path = base_path
    end

    def write(relative_path, content)
      output_path = File.join(self.base_path, relative_path)
      FileUtils.mkdir_p(File.dirname(output_path))
      File.open(output_path, "wb") do |file|
        file << content
      end
    end
  end
end