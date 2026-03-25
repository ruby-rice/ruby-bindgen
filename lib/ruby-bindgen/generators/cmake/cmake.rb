module RubyBindgen
  module Generators
    class CMake < Generator
      GuardedEntry = Data.define(:condition, :directories, :files)

      def self.template_dir
        __dir__
      end

      def include_dirs
        config[:include_dirs] || []
      end

      def guards
        @guards ||= begin
          config_guards = config[:guards] || {}
          config_guards.map do |condition, patterns|
            Guard.new(condition: condition, patterns: patterns, base_path: @inputter.base_path)
          end
        end
      end

      def generate
        base = Pathname.new(@inputter.base_path)

        # Collect files from inputter, grouped by relative directory
        files_by_dir = Hash.new do |hash, key|
          hash[key] = []
        end

        @inputter.each do |path, relative_path|
          dir = File.dirname(relative_path)
          files_by_dir[dir] << Pathname.new(path)
        end

        # Collect all directories that need CMakeLists.txt files
        # (directories containing files, plus all ancestor directories)
        all_dirs = Set.new
        files_by_dir.each_key do |dir|
          next if dir == "."
          parts = Pathname.new(dir).each_filename.to_a
          parts.length.times do |i|
            all_dirs << parts[0..i].join("/")
          end
        end

        # Build parent -> immediate child directories mapping
        child_dirs_of = Hash.new do |hash, key|
          hash[key] = []
        end
        all_dirs.each do |dir|
          parent = File.dirname(dir)
          parent = "." if parent == dir
          child_dirs_of[parent] << base.join(dir)
        end
        child_dirs_of.each_value(&:sort!)

        file_guards, directory_guards = build_guard_maps(files_by_dir, all_dirs.to_a)

        if @project
          # Root CMakeLists.txt
          content = render_template("project",
                                    :project => self.project,
                                    :directories => unguarded_paths(child_dirs_of["."], directory_guards, base),
                                    :files => unguarded_paths(files_by_dir["."].sort, file_guards, base),
                                    :guarded_entries => guarded_entries(child_dirs_of["."],
                                                                        directory_guards,
                                                                        files_by_dir["."].sort,
                                                                        file_guards,
                                                                        base),
                                    :include_dirs => self.include_dirs)
          self.outputter.write("CMakeLists.txt", content)

          # Presets
          content = render_template("presets")
          self.outputter.write("CMakePresets.json", content)
        end

        # Subdirectory CMakeLists.txt files
        all_dirs.sort.each do |dir|
          content = render_template("directory",
                                    :project => self.project,
                                    :directories => unguarded_paths(child_dirs_of[dir], directory_guards, base),
                                    :files => unguarded_paths((files_by_dir[dir] || []).sort, file_guards, base),
                                    :guarded_entries => guarded_entries(child_dirs_of[dir],
                                                                        directory_guards,
                                                                        (files_by_dir[dir] || []).sort,
                                                                        file_guards,
                                                                        base))
          self.outputter.write(File.join(dir, "CMakeLists.txt"), content)
        end
      end

      private

      def build_guard_maps(files_by_dir, all_dirs)
        file_paths = files_by_dir.values.flatten.map do |path|
          expand_path(path)
        end.sort
        directory_paths = all_dirs.map do |dir|
          expand_path(dir, @inputter.base_path)
        end.sort
        file_guards = {}
        directory_guards = {}

        guards.each do |guard|
          match = guard.match(file_paths: file_paths, directory_paths: directory_paths)

          match.files.each do |path|
            assign_guard!(file_guards, path, match.condition)
          end

          match.directories.each do |path|
            assign_guard!(directory_guards, path, match.condition)
          end
        end

        [file_guards, directory_guards]
      end

      def assign_guard!(assignments, path, condition)
        previous = assignments[path]
        if previous && previous != condition
          raise ArgumentError, "#{path} matched multiple guard conditions: #{previous.inspect}, #{condition.inspect}"
        end

        assignments[path] = condition
      end

      def guarded_entries(directories, directory_guards, files, file_guards, base)
        grouped = Hash.new do |hash, key|
          hash[key] = GuardedEntry.new(condition: key, directories: [], files: [])
        end

        directories.each do |directory|
          condition = directory_guards[expand_path(directory, base)]
          next unless condition

          grouped[condition].directories << directory
        end

        files.each do |file|
          condition = file_guards[expand_path(file, base)]
          next unless condition

          grouped[condition].files << file
        end

        guards.map(&:condition).filter_map do |condition|
          entry = grouped[condition]
          next if entry.nil? || (entry.directories.empty? && entry.files.empty?)

          entry
        end
      end

      def expand_path(path, base = @inputter.base_path)
        File.expand_path(path.to_s, base.to_s)
      end

      def unguarded_paths(paths, guard_map, base)
        paths.reject do |path|
          guard_map.key?(expand_path(path, base))
        end
      end

    end
  end
end

require_relative 'guard'
