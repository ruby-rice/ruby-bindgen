module RubyBindgen
  module Generators
    class CMake
      class Guard
        GuardMatch = Data.define(:condition, :directories, :files)

        attr_reader :condition, :patterns

        def initialize(condition:, patterns:, base_path:)
          @condition = condition.to_s
          @patterns = Array(patterns).map do |pattern|
            expand_path(pattern.to_s, base_path)
          end
        end

        def match(file_paths:, directory_paths:)
          matched_files = []
          matched_directories = []

          patterns.each do |pattern|
            files = file_paths.select do |path|
              path_match?(pattern, path)
            end
            directories = directory_paths.select do |path|
              path_match?(pattern, path)
            end

            warn_unmatched(pattern) if files.empty? && directories.empty?

            matched_files.concat(files)
            matched_directories.concat(directories)
          end

          GuardMatch.new(condition: condition,
                         directories: matched_directories.uniq.sort,
                         files: matched_files.uniq.sort)
        end

        private

        def path_match?(pattern, path)
          File.fnmatch?(pattern, path, File::FNM_PATHNAME)
        end

        def expand_path(path, base)
          File.expand_path(path.to_s, base.to_s)
        end

        def warn_unmatched(pattern)
          warn "CMake guard #{condition.inspect} did not match any generated paths for pattern #{pattern.inspect}"
        end
      end
    end
  end
end
