module RubyBindgen
  module Generators
    class CMake < Generator
      def self.template_dir
        __dir__
      end

      def include_dirs
        config[:include_dirs] || []
      end

      def generate
        base = Pathname.new(@inputter.base_path)

        # Collect files from inputter, grouped by relative directory
        files_by_dir = Hash.new { |h, k| h[k] = [] }

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
        child_dirs_of = Hash.new { |h, k| h[k] = [] }
        all_dirs.each do |dir|
          parent = File.dirname(dir)
          parent = "." if parent == dir
          child_dirs_of[parent] << base.join(dir)
        end
        child_dirs_of.each_value(&:sort!)

        # Root CMakeLists.txt
        content = render_template("project",
                                  :project => self.project,
                                  :directories => child_dirs_of["."],
                                  :files => files_by_dir["."].sort,
                                  :include_dirs => self.include_dirs)
        self.outputter.write("CMakeLists.txt", content)

        # Presets
        content = render_template("presets")
        self.outputter.write("CMakePresets.json", content)

        # Subdirectory CMakeLists.txt files
        all_dirs.sort.each do |dir|
          content = render_template("directory",
                                    :project => self.project,
                                    :directories => child_dirs_of[dir],
                                    :files => (files_by_dir[dir] || []).sort)
          self.outputter.write(File.join(dir, "CMakeLists.txt"), content)
        end
      end
    end
  end
end
