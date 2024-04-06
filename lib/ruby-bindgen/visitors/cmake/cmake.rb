module RubyBindgen
	module Visitors
		class CMake
			attr_reader :project, :outputter

			def initialize(project, outputter)
				@project = project
				@outputter = outputter
			end

			def create_project(path)
				rice_include_path = File.expand_path(File.join(Gem.find_files("rice").first, "..", "..", "include"))
				# Create top level CMakeLists.txt
				directories = path.children.find_all do |path|
					path.directory?
				end

				files = path.glob("*-rb.cpp")

				content = render_template("project", :rice_include_path => rice_include_path,
																	:project => self.project, :directories => directories, :files => files)
				self.outputter.write("CMakeLists.txt", content)
			end

			def create_directories(path)
				path.children.each do |child|
					next unless child.directory?

					directories = child.children.find_all do |path|
						path.directory?
					end

					files = child.glob("*-rb.cpp")

					# Create CMakeLists.txt
					content = render_template("directory",
																		:project => self.project, :directories => directories, :files => files)
					relative_path = child.relative_path_from(self.outputter.base_path)
					self.outputter.write(File.join(relative_path, "CMakeLists.txt"), content)

					self.create_directories(child)
				end
			end

			def visit_start
				pathname = Pathname.new(self.outputter.base_path)
				create_project(pathname)
				create_directories(pathname)
			end
		end
	end
end
