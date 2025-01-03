require 'set'

module RubyBindgen
  module Visitors
    class Rice
      CURSOR_LITERALS = [:cursor_integer_literal, :cursor_floating_literal,
                         :cursor_imaginary_literal, :cursor_string_literal,
                         :cursor_character_literal, :cursor_cxx_bool_literal_expr,
                         :cursor_cxx_null_ptr_literal_expr, :cursor_fixed_point_literal,
                         :cursor_unary_operator]

      CURSOR_CLASSES = [:cursor_class_decl, :cursor_class_template, :cursor_struct]

      attr_reader :project, :outputter

      def initialize(project, outputter)
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

        # Render C++ file
        STDOUT << "  Writing: " << rice_cpp << "\n"
        content = render_cursor(cursor, "translation_unit.cpp",
                                :init_name => init_name, :include => relative_path, :rice_header => rice_header)
        self.outputter.write(rice_cpp, content)

        # Render header file
        STDOUT << "  Writing: " << rice_header << "\n"
        content = render_cursor(cursor, "translation_unit.hpp",
                                :init_name => init_name)
        self.outputter.write(rice_header, content)
      end

      def visit_constructor(cursor)
        # Do not process class constructors defined outside of the class definition
        return if cursor.lexical_parent != cursor.semantic_parent

        # Do not process deleted constructors!
        return if cursor.deleted?

        # Do not construct abstract classes
        return if cursor.semantic_parent.abstract?

        signature = constructor_signature(cursor)
        args = arguments(cursor)

        return unless signature

        self.render_cursor(cursor, "constructor",
                           :signature => signature, :args => args)
      end

      def visit_class_decl(cursor)
        return if cursor.opaque_declaration?

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
        if !cursor.abstract? && constructors.empty?
          children << self.render_template("constructor",
                                         :cursor => cursor,
                                         :signature => self.constructor_signature(cursor), :args => [])

        end

        children += visit_children(cursor,
                                  :exclude_kinds => [:cursor_class_decl, :cursor_struct, :cursor_enum_decl, :cursor_typedef_decl])
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

      def type_spellings(cursor)
        cursor.type.arg_types.map do |arg_type|
          type_spelling(arg_type)
        end
      end

      def type_spelling(type)
        result = case type.kind
                   when :type_elaborated
                     # Deal with any types a class template defines for itself
                     spelling = if type.declaration.kind == :cursor_class_template
                                  spelling = type.spelling
                                  if type.spelling.match(/\w+::/)
                                    spelling
                                  else
                                    spelling.sub(type.declaration.spelling, type.declaration.qualified_name)
                                  end
                                elsif type.declaration.kind == :cursor_typedef_decl && type.declaration.semantic_parent.kind == :cursor_class_template
                                 "#{type.const_qualified? ? "const " : ""}#{type.declaration.semantic_parent.qualified_display_name}::#{type.spelling.sub("const ", "")}"
                                elsif type.declaration.kind == :cursor_typedef_decl
                                  #type.declaration.underlying_type.spelling
                                  "#{type.const_qualified? ? "const " : ""}#{type.declaration.qualified_name}"
                                elsif type.canonical.kind == :type_unexposed
                                  spelling = type.spelling
                                  if spelling.match(/\w+::/)
                                    spelling
                                  else
                                    spelling.sub(type.declaration.spelling, type.declaration.qualified_name)
                                  end
                                elsif type.canonical.kind == :type_nullptr
                                  type.spelling
                                elsif type.declaration.semantic_parent.kind != :cursor_invalid_file
                                  "#{type.const_qualified? ? "const " : ""}#{spelling}#{type.declaration.qualified_display_name}"
                                else
                                  type.spelling
                                end
                   when :type_lvalue_ref
                    "#{type_spelling(type.non_reference_type)}&"
                  when :type_rvalue_ref
                    "#{type_spelling(type.non_reference_type)}&&"
                  when :type_pointer
                    "#{type_spelling(type.pointee)}*"
                   when :type_incomplete_array
                     # This is a parameter like T[]
                     type.canonical.spelling
                  else
                    type.spelling
                 end

        # Horrible hack
        namespace = type.declaration.qualified_namespace
        #if namespace && result.match(/const/) && !result.match("#{namespace}::")
        #  result.gsub(/const\s*(.*)/, "const #{namespace}::\\1")
        if namespace && !result.match("::") && !result.match("#{namespace}::")
          "#{namespace}::#{result}"
        else
          result
        end
      end

      def constructor_signature(cursor)
        signature = Array.new

        case cursor.kind
          when :cursor_constructor
            # Constructors have qualified names like MyClass::MyClass so remove the
            # last part. Unless this is a specialization of a template like
            # MyClass::MyClass<T>
            parts = cursor.qualified_name.split("::")
            if parts[-2] == parts[-1]
              parts.pop
            end
            signature << parts.join("::")
            params = type_spellings(cursor)
            signature += params

          when :cursor_class_decl
            signature << cursor.class_name_cpp
          when :cursor_struct
            signature << cursor.class_name_cpp
          else
            raise("Unsupported cursor kind: #{cursor.kind}")
        end

        result = signature.compact.join(", ")

        if result.match(/std::initializer_list/)
          nil
        else
          result
        end
      end

      def arguments(cursor)
        params = cursor.find_by_kind(false, :cursor_parm_decl)
        params.map do |param|
          result = "Arg(\"#{param.spelling.underscore}\")"
          literals = param.find_by_kind(true, *CURSOR_LITERALS)
          if !literals.empty?
            result << " = "
            literals.each do |literal|
              tokens = cursor.translation_unit.tokenize(literal.extent)
              result << (tokens&.first ? tokens.first.spelling : "NULL")
            end
          end
          result
        end
      end

      def parameter_type(param_children)
        result = ""
        cursor = param_children.shift
        if cursor.nil?
          return result
        end

        case cursor.kind
          when :cursor_template_ref
            result << cursor.referenced.qualified_name
            result << "<"
            result << parameter_type(param_children)
            result << ">"
          when :cursor_ref_type
            result << cursor.spelling
          when :cursor_type_ref
            # Horrible hack
            result << if cursor.spelling.match(/</)
                        "#{cursor.referenced.qualified_namespace}::#{cursor.spelling}"
                      else
                        cursor.type.spelling
                      end
          when :cursor_cxx_typeid_expr
            result << cursor.type.spelling
          when :cursor_namespace_ref
            #result << cursor.spelling << "::"
            result << parameter_type(param_children)
          when :cursor_unexposed_expr
            result << cursor.type.spelling
          when :cursor_integer_literal, :cursor_unary_operator
            # Default value, do nothing
          else
            raise "Unsupported cursor kind: #{cursor.kind}"
        end
        result
      end

      def method_signature(cursor)
        param_types = type_spellings(cursor)
        result_type = type_spelling(cursor.type.result_type)

        signature = Array.new
        if cursor.kind == :cursor_function || cursor.static?
          signature << "#{result_type}(*)(#{param_types.join(', ')})"
        else
          signature << "#{result_type}(#{cursor.semantic_parent.qualified_display_name}::*)(#{param_types.join(', ')})"
        end

        if cursor.const?
          signature << "const"
        end

        if cursor.type.exception_specification == :basic_noexcept
          signature << "noexcept"
        end

        result = "<#{signature.join(' ')}>"

        if result.match(/std::initializer_list/)
          nil
        else
          result
        end
      end

      def visit_cxx_method(cursor)
        # Do not process method definitions outside of classes (because we already processed them)
        return if cursor.lexical_parent != cursor.semantic_parent

        # Can't return arrays in C++
        return if cursor.type.result_type.is_a?(::FFI::Clang::Types::Array)

        # Is this an iterator?
        if ["begin", "end", "rbegin", "rend"].include?(cursor.spelling)
          return visit_cxx_iterator_method(cursor)
        end

        name = cursor.ruby_name
        signature = method_signature(cursor)
        args = arguments(cursor)

        if signature
          is_template =  cursor.semantic_parent.kind == :cursor_class_template
          self.render_cursor(cursor, "cxx_method",
                             :name => name, :is_template => is_template,
                             :signature => signature, :args => args)
        end
      end

      def visit_cxx_iterator_method(cursor)
        iterator_name = case cursor.spelling
                          when "begin"
                            cursor.const? ? "each_const" : "each"
                          when "rbegin"
                            cursor.const? ? "each_reverse_const" : "each_reverse"
                          else
                            # We don't care about end methods
                            return
                        end

        begin_method = cursor.spelling
        end_method = begin_method.sub("begin", "end")
        is_template =  cursor.semantic_parent.kind == :cursor_class_template
        signature = method_signature(cursor)

        return unless signature

        self.render_cursor(cursor, "cxx_iterator_method", :name => iterator_name,
                           :begin_method => begin_method, :end_method => end_method,
                           :signature => signature,
                           :is_template => is_template)
      end

      def visit_conversion_function(cursor)
        # For now only deal with member functions
        return unless CURSOR_CLASSES.include?(cursor.lexical_parent.kind)

        return unless cursor.type.args_size == 0
        match = cursor.spelling.match(/ ([^<]+)/)
        return unless match

        ruby_name = "to_#{match[1].underscore}"
        result_type = type_spelling(cursor.type.result_type)
        self.render_cursor(cursor, "conversion_function",
                           :ruby_name => ruby_name, :result_type => result_type)
      end

      def visit_enum_decl(cursor)
        return unless cursor.public?

        # Enum hack used in old C++ code before static const in classes
        result = if cursor.anonymous? && CURSOR_CLASSES.include?(cursor.semantic_parent.kind)
          cursor.find_by_kind(false, :cursor_enum_constant_decl).map do |child|
            self.render_cursor(child, "constant",
                               :name => child.spelling,
                               :qualified_name => "#{cursor.semantic_parent.qualified_name}::#{child.spelling}")
          end
        else
          under = cursor.ancestors_by_kind(:cursor_class_decl, :cursor_struct, :cursor_namespace).first
          children = render_children(cursor, indentation: 2, separator: ".\n")
          self.render_cursor(cursor, "enum_decl", :under => under, :children => children)
        end
        result
      end

      def visit_enum_constant_decl(cursor)
        self.render_cursor(cursor, "enum_constant_decl")
      end

      def visit_function(cursor)
        # Can't return arrays in C++
        return if cursor.type.result_type.is_a?(::FFI::Clang::Types::Array)

        if cursor.spelling.match(/operator/)
          self.visit_operator_non_member(cursor)
        else
          name = cursor.ruby_name
          args = arguments(cursor)
          signature = method_signature(cursor)
          under = cursor.ancestors_by_kind(:cursor_namespace).first
          self.render_cursor(cursor, "function", :under => under, :name => name,
                             :signature => signature, :args => args)
        end
      end

      def visit_macro_definition(cursor)
        tokens = cursor.translation_unit.tokenize(cursor.extent)
        return unless tokens.size == 2
        return unless tokens.tokens[0].kind == :identifier
        return unless tokens.tokens[1].kind == :literal

        self.render_cursor(cursor, "constant",
                           :name => tokens.tokens[0].spelling,
                           :qualified_name => tokens.tokens[0].spelling)
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
        return unless cursor.public?

          # Can't return arrays in C++
        return if cursor.type.is_a?(::FFI::Clang::Types::Array)

        self.render_cursor(cursor, "field_decl")
      end

      def visit_operator_non_member(cursor)
        # This is a stand-alone operator, such as:
        #
        #   MatExpr operator + (const Mat& a, const Mat& b);
        #   std::ostream& operator << (std::ostream& out, const Complex<_Tp>& c)

        return if cursor.type.args_size != 2

        class_cursor = cursor.type.arg_type(0).non_reference_type.declaration

        # This can happen when the first operator is a fundamental type like double
        return if class_cursor.kind == :cursor_no_decl_found

        # Make sure we have seen the cursor class, it could be in a different translation unit!
        #return unless class_cursor.location.file == cursor.translation_unit.spelling

        class_cursor.location.file == cursor.translation_unit.spelling

        self.render_cursor(cursor, "operator_non_member", :class_cursor => class_cursor)
      end

      def visit_type_alias_decl(cursor)
        return if cursor.semantic_parent.kind == :cursor_class_decl

        case cursor.underlying_type.kind
        when :type_elaborated
          # If this is a struct or a union or enum we have already rendered it
          return if [:type_record, :type_enum].include?(cursor.underlying_type&.canonical&.kind)
        when :type_pointer
          #if cursor.underlying_type.function?
          #  return self.visit_callback(cursor.ruby_name, cursor.find_by_kind(false, :cursor_parameter_decl), cursor.underlying_type.pointee)
          #end
        end
        #render_cursor(cursor)
      end

      def visit_typedef_decl(cursor)
        return if cursor.semantic_parent.kind == :cursor_class_decl || cursor.semantic_parent.kind == :cursor_struct
        children = cursor.map {|child, parent| child}
        cursor_template = children[0]
        return unless cursor_template && cursor_template.kind == :cursor_template_ref

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

        children = render_children(cursor, indentation: 2, separator: ".\n")
        result << self.render_cursor(cursor, "union", :children => children)
        result.join("\n")
      end

      def visit_variable(cursor)
        if CURSOR_CLASSES.include?(cursor.semantic_parent.kind) &&
          !cursor.public?
          return
        end

        if cursor.type.const_qualified?
          visit_variable_constant(cursor)
        else
          self.render_cursor(cursor, "variable")
        end
      end

      def visit_variable_constant(cursor)
        self.render_cursor(cursor, "constant",
                           :name => cursor.spelling,
                           :qualified_name => cursor.qualified_name)
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

          unless child_cursor.declaration? || child_cursor.kind == :cursor_macro_definition
            next :continue
          end

          if child_cursor.forward_declaration?
            next :continue
          end

          # Skip static variables and static functions
          #if child_cursor.linkage == :internal && !child_cursor.spelling.match(/operator/)
          #  next :continue
          #end

          if exclude_kinds.include?(child_cursor.kind)
            next :continue
          end

          visit_method = self.figure_method(child_cursor)
          if self.respond_to?(visit_method)
            content = self.send(visit_method, child_cursor)
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