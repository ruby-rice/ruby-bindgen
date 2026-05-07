# frozen_string_literal: true

require 'find'
require 'pathname'

module RubyBindgen
  class Inputter
    include Enumerable
    attr_reader :base_path, :globs, :exclude_glob

    def initialize(base_path, globs=nil, exclude_glob=[])
      @base_path = base_path
      @globs = Array(globs).empty? ? ["**/*.{h,hpp}"] : Array(globs)
      @exclude_glob = exclude_glob

      if RUBY_PLATFORM.match?(/mswin/) || RUBY_PLATFORM.match?(/mingw/)
        @base_path = @base_path.gsub('\\', '/')
        @globs = @globs.map { |g| g.gsub('\\', '/') }
        @exclude_glob = @exclude_glob.map { |g| g.gsub('\\', '/') }
      end
    end

    def each
      raise(ArgumentError, "No block given") unless block_given?

      yielded = 0
      seen = Set.new
      self.globs.each do |glob|
        search = File.join(self.base_path, glob)
        Dir.glob(search).each do |path|
          next if exclude.include?(path)
          next unless seen.add?(path)

          yielded += 1
          relative_path = Pathname.new(path).relative_path_from(self.base_path)
          yield path, relative_path.to_path
        end
      end

      # Silent empty output is one of the most common config mistakes. Warn
      # so a typo'd match: glob doesn't look like a successful run.
      if yielded.zero?
        warn "ruby-bindgen: no input files matched #{self.globs.inspect} under #{self.base_path}"
      end
    end

    def exclude
      @exclude ||= self.exclude_glob.map do |exclude|
        search = File.join(self.base_path, exclude)
        Dir.glob(search)
      end.flatten.uniq
    end
  end
end