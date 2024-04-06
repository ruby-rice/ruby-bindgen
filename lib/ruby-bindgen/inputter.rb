# frozen_string_literal: true

require 'find'
require 'pathname'

module RubyBindgen
  class Inputter
    include Enumerable
    attr_reader :base_path, :glob, :exclude_glob

    def initialize(base_path, glob=nil, exclude_glob=[])
      if RUBY_PLATFORM.match?(/mswin/) || RUBY_PLATFORM.match?(/mingw/)
        @base_path = base_path.gsub('\\', '/')
        @glob = glob.gsub('\\', '/') if glob
        @exclude_glob = exclude_glob.map do |glob|
          glob.gsub('\\', '/')
        end
      else
        @base_path = base_path
        @glob = glob || "**/*.{h,hpp}"
        @exclude_glob = exclude_glob
      end
    end

    def each
      raise(ArgumentError, "No block given") unless block_given?

      search = File.join(self.base_path, self.glob)
      Dir.glob(search).each do |path|
        if exclude.include?(path)
          next
        end

        relative_path = Pathname.new(path).relative_path_from(self.base_path)
        yield path, relative_path.to_path
      end
    end

    def exclude
      @exclude ||= self.exclude_glob.map do |exclude|
        search = File.join(self.base_path, exclude)
        Dir.glob(search)
      end.flatten.uniq
    end

    # def directory_files(directory)
    #   raise(ArgumentError, "No block given") unless block_given?
    #   raise(ArgumentError, "Must specify directory: #{directory}") unless File.directory?(directory)
    #
    #   self.each(directory) do |path, relative_path|
    #     if File.dirname(path) == directory
    #       yield path, relative_path
    #     end
    #   end
    # end
    #
    # def directories(directory)
    #   raise(ArgumentError, "No block given") unless block_given?
    #   raise(ArgumentError, "Must specify directory: #{directory}") unless File.directory?(directory)
    #
    #   self.each(directory) do |path, relative_path|
    #     if File.directory?(path) && File.dirname(path) == directory
    #       yield path, relative_path
    #     end
    #   end
    # end
  end
end