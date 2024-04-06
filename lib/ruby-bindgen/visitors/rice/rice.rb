  require 'erb'
require 'set'

module RubyBindgen
  module Visitors
    class Rice
      attr_reader :project, :outputter

      def initialize(project, outputter)
        # Project names are used to create init methods in the form
        # Init_<project>. Thus they must be valid C++ identifiers
        unless project.match(/[A-Za-z0-9_]+/)
          raise(ArgumentError, "Project names must be valid C++ method names")
        end
        @project = project.gsub(/-/, '_')
        @outputter = outputter
        @init_names = Hash.new
        @namespaces = Set.new
      end

      def visit_start
      end

      def visit_end
        # create_project_files
        create_def_file

        pathname = Pathname.new(self.outputter.base_path)
        #create_cmake_master(pathname)
        #create_cmake_directories(pathname)
      end

      def visit_translation_unit(translation_unit, path, relative_path)
        @namespaces.clear

        cursor = translation_unit.cursor

        # Figure out relative paths for generated header and cpp file
        basename = "#{File.basename(relative_path, ".*")}-rb"
        rice_header = File.join(File.dirname(relative_path), "#{basename}.hpp")
        rice_cpp = File.join(File.dirname(relative_path), "#{basename}.cpp")

        # Track init names
        init_name = "Init_#{File.basename(cursor.spelling, ".*").camelize}"
        @init_names[rice_header] = init_name

        # Render header file
        STDOUT << "  Writing: " << rice_header << "\n"
        content = render_cursor(cursor, "translation_unit.hpp",
                                :init_name => init_name)
        self.outputter.write(rice_header, content)

        # Render C++ file
        STDOUT << "  Writing: " << rice_cpp << "\n"
        content = render_cursor(cursor, "translation_unit.cpp",
                                :init_name => init_name, :include => relative_path, :rice_header => rice_header)
        self.outputter.write(rice_cpp, content)
      end

      def visit_constructor(cursor)
        # Do not process class constructors defined outside of the class definition
        return if cursor.lexical_parent != cursor.semantic_parent

        # Do not process deleted constructors!
        return if cursor.deleted?

        signature = constructor_signature(cursor)

        self.render_cursor(cursor, "constructor",
                           :signature => signature)
      end

      def visit_class_decl(cursor)
        if cursor.opaque_declaration?
          return ""
        end

        #  if cursor.abstract?
        #  return ""
        #end

        result = Array.new

        # Determine containing module
        under = cursor.ancestors_by_kind(:cursor_class_decl, :cursor_struct, :cursor_namespace).first

        # Is there a base class?
        base = nil
        base_class = cursor.find_by_kind(false, :cursor_cxx_base_specifier).first
        if base_class
          # Base class children can be a :cursor_type_ref or :cursor_template_ref
          type_ref = base_class.find_by_kind(false, :cursor_type_ref, :cursor_template_ref).first
          base = type_ref.definition
        end


        # Visit children
        children = Array.new

        # Are there any constructors? If not, C++ will define one implicitly
        constructors = cursor.find_by_kind(false, :cursor_constructor)
        if constructors.empty?
          children << self.render_template("constructor",
                                         :cursor => cursor,
                                         :signature => self.constructor_signature(cursor))

        end

        children += visit_children(cursor,
                                  :exclude_kinds => [:cursor_class_decl, :cursor_struct, :cursor_enum_decl])
        children_content = merge_children(children, :indentation => 2, :separator => ".\n", :strip => true)

        # Render class
        result << self.render_cursor(cursor, "class", :under => under, :base => base,
                                     :children => children_content)

        # Define any embedded classes
        cursor.find_by_kind(false, :cursor_class_decl).each do |child_cursor|
          result << visit_class_decl(child_cursor)
        end

        # Define any embedded structs
        cursor.find_by_kind(false, :cursor_struct).each do |child_cursor|
          result << visit_struct(child_cursor)
        end

        # Define any embedded enums
        cursor.find_by_kind(false, :cursor_enum_decl).each do |child_cursor|
          result << visit_enum_decl(child_cursor)
        end

        merge_children(result)
      end
      alias :visit_struct :visit_class_decl

      def visit_class_template_builder(cursor)
        template_parameter_kinds = [:cursor_template_type_parameter,
                                    :cursor_non_type_template_parameter,
                                    :cursor_template_template_parameter]

        template_parameters = cursor.find_by_kind(false, *template_parameter_kinds)
        template_signature = template_parameters.map do |template_parameter|
          if template_parameter.kind == :cursor_template_type_parameter
            "typename #{template_parameter.spelling}"
          else
            "#{template_parameter.type.spelling} #{template_parameter.spelling}"
          end
        end.join(", ")

        # Visit children
        children = visit_children(cursor,
                                  :exclude_kinds => [:cursor_typedef_decl, :cursor_alias_decl])
        children_content = merge_children(children, :indentation => 4, :separator => ".\n", :strip => true)

        # Determine containing module
        under = cursor.ancestors_by_kind(:cursor_class_decl, :cursor_struct, :cursor_namespace).first

        # Render class
        result = Array.new
        result << self.render_cursor(cursor, "class_template", :under => under,
                                     :template_signature => template_signature, :children => children_content)

        merge_children(result, indentation: 0, separator: ".\n", strip: false)
      end

      def type_spelling(type)
        result = case type.kind
                  when :type_elaborated
                    if type.canonical.kind == :type_unexposed
                      type.spelling
                    else
                      type.canonical.spelling
                    end
                  when :type_lvalue_ref
                    "#{type_spelling(type.non_reference_type)}&"
                  when :type_rvalue_ref
                    "#{type_spelling(type.non_reference_type)}&&"
                  when :type_pointer
                    "#{type_spelling(type.pointee)}*"
                  else
                    type.spelling
                 end

        # Horrible hack
        namespace = type.declaration.qualified_namespace
        if namespace && result.match(/const/) && !result.match("#{namespace}::")
          result.gsub(/const\s*(.*)/, "const #{namespace}::\\1")
        elsif namespace && !result.match("#{namespace}::")
          "#{namespace}::#{result}"
        else
          result
        end
      end

      def constructor_signature(cursor)
        signature = Array.new

        case cursor.kind
          when :cursor_constructor
            #puts cursor.display_name
            signature << "#{cursor.qualified_namespace}::#{cursor.spelling}"
            signature += parameters_signature(cursor)

          when :cursor_class_decl
            signature << cursor.qualified_display_name
          when :cursor_struct
            signature << cursor.qualified_display_name
          else
            raise("Unsupported cursor kind: #{cursor.kind}")
        end
        signature = signature.compact.join(", ")
      end

      def parameters_signature(cursor)
        cursor.type.arg_types.map do |arg_type|
          type_spelling(arg_type)
        end
      end

      def method_signature(cursor)
        types = cursor.type.arg_types.map do |arg_type|
          type_spelling(arg_type)
        end

        result_type = type_spelling(cursor.type.result_type)

        signature = Array.new
        if cursor.kind == :cursor_function || cursor.static?
          signature << "#{result_type}(*)(#{types.join(', ')})"
        else
          signature << "#{result_type}(#{cursor.semantic_parent.qualified_display_name}::*)(#{types.join(', ')})"
        end

        if cursor.const?
          signature << "const"
        end

        if cursor.type.exception_specification == :basic_noexcept
          signature << "noexcept"
        end

        "<#{signature.join(' ')}>"
      end

      def visit_cxx_method(cursor)
          # Do not process method definitions outside of classes (because we already processed them)
        return if cursor.lexical_parent != cursor.semantic_parent

        # Can't return arrays in C++
        return if cursor.type.result_type.is_a?(::FFI::Clang::Types::Array)

        name = cursor.ruby_name
        signature = method_signature(cursor)
        if signature
          is_template =  cursor.semantic_parent.kind == :cursor_class_template
          self.render_cursor(cursor, "cxx_method", :name => name, :signature => signature, :is_template => is_template)
        end
      end

      def visit_conversion_function(cursor)
        # Skip for now, doesn't handle custom conversion functions
        #self.render_cursor(cursor, "conversion_function")
      end

      def visit_enum_decl(cursor)
        unless cursor.anonymous?
          under = cursor.ancestors_by_kind(:cursor_class_decl, :cursor_struct, :cursor_namespace).first
          children = render_children(cursor, indentation: 2, separator: ".\n")
          self.render_cursor(cursor, "enum_decl", :under => under, :children => children)
        end
      end

      def visit_enum_constant_decl(cursor)
        self.render_cursor(cursor, "enum_constant_decl")
      end

      def visit_function(cursor)
        # Can't return arrays in C++
        return if cursor.type.result_type.is_a?(::FFI::Clang::Types::Array)

        name = cursor.ruby_name
        signature = method_signature(cursor)
        under = cursor.ancestors_by_kind(:cursor_namespace).first
        self.render_cursor(cursor, "function", :under => under, :name => name, :signature => signature)
      end

      def visit_namespace(cursor)
        result = Array.new

        # Don't redefine a namespace twice. It doesn't matter to Ruby, but C++ wrapper
        # will break with a redefinition error:
        #   Module rb_mNamespace = define_module("namespace");
        #   Module rb_mNamespace = define_module("namespace");
        qualified_display_name = cursor.qualified_display_name
        unless @namespaces.include?(qualified_display_name)
          @namespaces << qualified_display_name
          under = cursor.ancestors_by_kind(:cursor_class_decl, :cursor_struct, :cursor_namespace).first
          result << self.render_cursor(cursor, "namespace", :under => under)
        end

        result << self.render_children(cursor)
        result.join("\n")
      end

      def visit_field_decl(cursor)
        # Can't return arrays in C++
        return if cursor.type.is_a?(::FFI::Clang::Types::Array)

        self.render_cursor(cursor, "field_decl")
      end

      def visit_type_alias_decl(cursor)
        case cursor.underlying_type.kind
        when :type_elaborated
          # If this is a struct or a union or enum we have already rendered it
          return if [:type_record, :type_enum].include?(cursor.underlying_type&.canonical&.kind)
        when :type_pointer
          if cursor.underlying_type.function?
            return self.visit_callback(cursor.ruby_name, cursor.find_by_kind(false, :cursor_parameter_decl), cursor.underlying_type.pointee)
          end
        end
        #render_cursor(cursor)
      end

      def visit_typedef_decl(cursor)
        children = cursor.map {|child, parent| child}
        cursor_template = children[0]
        return unless cursor_template.kind == :cursor_template_ref

        template_arguments = cursor.underlying_type.canonical.spelling.match(/\<(.*)\>/)[1]
        under = cursor.ancestors_by_kind(:cursor_class_decl, :cursor_struct, :cursor_namespace).first
        template_specialization = type_spelling(cursor.underlying_type)

        self.render_cursor(cursor, "class_template_specialization",
                           :cursor_template => cursor_template,
                           :template_specialization => template_specialization,
                           :template_arguments => template_arguments,
                           :under => under)
      end

      def visit_union(cursor)
        return if cursor.forward_declaration?
        return if cursor.anonymous?

        result = Array.new

        # Define any embedded unions
        cursor.find_by_kind(false, :cursor_union).each do |struct|
          result << visit_struct(struct)
        end

        # Define any embedded structures
        cursor.find_by_kind(false, :cursor_struct).each do |struct|
          result << visit_struct(struct)
        end

        # Define any embedded callbacks
        cursor.find_by_kind(false, :cursor_field_decl).each do |field|
          if field.type.is_a?(::FFI::Clang::Types::Pointer) && field.type.function?
            callback_name = "#{cursor.ruby}_#{field.ruby}_callback"
            result << self.visit_callback(callback_name, field.parameters, field.type.pointee)
          end
        end

        children = render_children(cursor, indent: true, separator: ".\n")
        result << self.render_cursor(cursor, "union", :children => children)
        result.join("\n")
      end

      def visit_variable(cursor)
        self.render_cursor(cursor, "variable")
      end

      def create_project_files
        # Create master hpp/cpp files to include all the files we generated
        basename = "#{project}-rb"
        rice_header = "#{basename}.hpp"
        rice_cpp = "#{basename}.cpp"
        init_function = "Init_#{project}"

        content = render_template("project.hpp",
                                  :init_name => init_function, :init_names => @init_names)
        self.outputter.write(rice_header, content)

        content = render_template("project.cpp",
                                  :project_header => rice_header, :init_name => init_function, :init_names => @init_names)
        self.outputter.write(rice_cpp, content)
      end

      def create_def_file
        # Create def file to export Init function
        def_name = "#{project}.def"
        init_function = "Init_#{project}"

        content = render_template("project.def", :init_function => init_function)
        self.outputter.write(def_name, content)
      end

      def create_cmake_master(path)
        # Create top level CMakeLists.txt
        directories = path.children.find_all do |path|
          path.directory?
        end

        files = path.glob("*-rb.cpp")

        content = render_template("cmake_project",
                                  :project => self.project, :directories => directories, :files => files)
        self.outputter.write("CMakeLists.txt", content)
      end

      def create_cmake_directories(path)
        path.children.each do |child|
          next unless child.directory?

          directories = child.children.find_all do |path|
            path.directory?
          end

          files = child.glob("*-rb.cpp")

          # Create CMakeLists.txt
          content = render_template("cmake_directory",
                                    :project => self.project, :directories => directories, :files => files)
          relative_path = child.relative_path_from(self.outputter.base_path)
          self.outputter.write(File.join(relative_path, "CMakeLists.txt"), content)

          self.create_cmake_directories(child)
        end
      end

      def figure_method(cursor)
        name = cursor.kind.to_s.delete_prefix("cursor_")
        "visit_#{name.underscore}".to_sym
      end

      def add_indentation(content, indentation)
        content.lines.map do |line|
          " " * indentation + line
        end.join
      end

      def render_cursor(cursor, template, local_variables = {})
        render_template(template, local_variables.merge(:cursor => cursor))
      end

      def render_template(template, local_variables = {})
        template_path = File.join(__dir__, "#{template}.erb")
        template_content = File.read(template_path)
        template = ERB.new(template_content, :trim_mode => '-')
        template.filename = template_path # This allows debase to stop at breakpoints in templates!
        b = self.binding
        local_variables.each do |key, value|
          b.local_variable_set(key, value)
        end
        template.result(b)
      end

      def render_class_templates(cursor, indentation: 0, separator: "\n", strip: false)
        results = Array.new
        cursor.find_by_kind(true, :cursor_class_template).each do |class_template_cursor|
          if class_template_cursor.private? || class_template_cursor.protected?
            next :continue
          end

          if class_template_cursor.location.in_system_header?
            next :continue
          end

          unless class_template_cursor.location.from_main_file?
            next :continue
          end

          results << visit_class_template_builder(class_template_cursor)
        end
        result = merge_children(results, :indentation => indentation, :separator => separator, :strip => strip)
      end

      def visit_children(cursor, exclude_kinds: Set.new)
        results = Array.new
        cursor.each(false) do |child_cursor, parent_cursor|
          if child_cursor.location.in_system_header?
            next :continue
          end

          unless child_cursor.location.from_main_file?
            next :continue
          end

          # For some reason child.cursor.public? filters out way too much
          if child_cursor.private? || child_cursor.protected?
            next :continue
          end

          if child_cursor.deleted?
            next :continue
          end

          unless child_cursor.declaration?
            next :continue
          end

          if child_cursor.forward_declaration?
            next :continue
          end

          # Skip static variables and static functions
          if child_cursor.linkage == :internal
            next :continue
          end

          if exclude_kinds.include?(child_cursor.kind)
            next :continue
          end

          visit_method = self.figure_method(child_cursor)
          if self.respond_to?(visit_method)
            content = self.send(self.figure_method(child_cursor), child_cursor)
            unless content.nil? || content.empty?
              results << content
            end
          end
          next :continue
        end
        results
      end

      def merge_children(children, indentation: 0, separator: "\n", strip: false)
        if strip
          children.each {|line| line.rstrip!}
        end

        # Join together templates
        children = children.join(separator)
        children = add_indentation(children, indentation) if indentation > 0

        children
      end

      def render_children(cursor, indentation: 0, separator: "\n", strip: false, exclude_kinds: Set.new)
        children = visit_children(cursor)
        merge_children(children, indentation: indentation, separator: separator, strip: strip)
      end
    end
  end
end