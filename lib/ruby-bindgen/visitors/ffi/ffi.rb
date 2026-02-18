require 'erb'

module RubyBindgen
  module Visitors
    class FFI
      attr_reader :library_names, :library_versions, :project, :outputter

      def initialize(outputter, project = nil, library_names: [], library_versions: [])
        @project = project&.gsub(/-/, '_')
        @outputter = outputter
        @library_names = library_names
        @library_versions = library_versions
        @indentation = 0
      end

      def visit_start
      end

      def visit_translation_unit(translation_unit, path, relative_path)
        basename = "#{File.basename(relative_path, ".*")}"
        relative_path_2 = File.join(File.dirname(relative_path), "#{basename}.rb")

        cursor = translation_unit.cursor
        content = render_children(cursor, :indentation => 2)
        result = render_cursor(cursor, "translation_unit", :content => content.rstrip)
        result.gsub!(/\n\n\n/, "\n\n")
        self.outputter.write(relative_path_2, result)
      end

      def visit_end
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

          if exclude_kinds.include?(child_cursor.kind)
            next :continue
          end

          visit_method = self.figure_method(child_cursor)
          if self.respond_to?(visit_method)
            content = self.send(visit_method, child_cursor)
            case content
              when Array
                results += content
              when String
                results << content
            end
          end
          next :continue
        end
        results
      end

      def merge_children(children, indentation: 0, separator: "\n", terminator: "", strip: false)
        return "" if children.empty?

        children = children.map do |line|
          strip ? line.rstrip : line
        end

        # Join together templates
        children = children.join(separator) + terminator
        children = add_indentation(children, indentation) if indentation > 0

        children
      end

      def render_children(cursor, indentation: 0, separator: "\n", terminator: "", strip: false, exclude_kinds: Set.new)
        children = visit_children(cursor, exclude_kinds: exclude_kinds)
        merge_children(children, indentation: indentation, separator: separator, terminator: terminator, strip: strip)
      end

      def visit_callback(name, parameters, type)
        parameter_types = parameters.map do |parameter|
          if parameter.find_first_by_kind(false, :cursor_type_ref) && parameter.type.is_a?(::FFI::Clang::Types::Pointer)
            ":pointer"
          else
            figure_ffi_type(parameter.type, :callback)
          end
        end
        self.render_callback(name, parameter_types, type.result_type)
      end

      def visit_enum_decl(cursor)
        children = render_children(cursor, indentation: 2, separator: ",\n", strip: true)
        self.render_cursor(cursor, "enum_decl", :children => children)
      end

      def visit_enum_constant_decl(cursor)
        self.render_cursor(cursor,"enum_constant_decl")
      end

      def visit_function(cursor)
        result = Array.new
        parameter_types = cursor.find_by_kind(false, :cursor_parm_decl).map do |parameter|
          callback_name = "#{cursor.spelling}_#{parameter.spelling}_callback"
          if parameter.type.is_a?(::FFI::Clang::Types::Pointer) && parameter.type.function?
            parameters = parameter.find_by_kind(false, :cursor_parm_decl)
            result << self.visit_callback(callback_name, parameters, parameter.type.pointee)
          end

          if parameter.type.is_a?(::FFI::Clang::Types::Pointer) && parameter.type.function?
            ":#{callback_name}"
          else
            figure_ffi_type(parameter.type, :function)
          end
        end
        result << self.render_cursor(cursor, "function", :parameter_types => parameter_types)
        result.join("\n")
      end

      def visit_struct(cursor)
        return if cursor.forward_declaration?

        result = Array.new

        # Define any embedded structures
        cursor.find_by_kind(false, :cursor_struct).each do |struct|
          result << visit_struct(struct)
        end

        # Define any embedded unions
        cursor.find_by_kind(false, :cursor_union).each do |union|
          result << visit_union(union)
        end

        # Define any embedded callbacks
        cursor.find_by_kind(false, :cursor_field_decl).each do |field|
          if field.type.is_a?(::FFI::Clang::Types::Pointer) && field.type.function?
            callback_name = "#{cursor.spelling}_#{field.spelling}_callback"
            parameters = field.find_by_kind(false, :cursor_parm_decl)
            result << self.visit_callback(callback_name, parameters, field.type.pointee)
          end
        end

        children = render_children(cursor, indentation: 9, separator: ",\n", strip: true,
                                           exclude_kinds: [:cursor_struct, :cursor_union])

        result << self.render_cursor(cursor, "struct", :children => children.lstrip)
        result.join("\n")
      end

      def visit_field_decl(cursor)
        ffi_type = if cursor.type.is_a?(::FFI::Clang::Types::Pointer)
                      if cursor.type.function?
                        ":#{cursor.semantic_parent.spelling}_#{cursor.spelling}_callback"
                      elsif cursor.type.forward_declaration?
                       ":pointer"
                      end
                    end

        ffi_type ||= figure_ffi_type(cursor.type, :structure)
        self.render_cursor(cursor, "field_decl", ffi_type: ffi_type)
      end

      def visit_typedef_decl(cursor)
        case cursor.underlying_type.kind
          when :type_elaborated
            # If this is a struct or a union or enum we have already rendered it
            return if [:type_record, :type_enum].include?(cursor.underlying_type&.canonical&.kind)
          when :type_pointer
            if cursor.underlying_type.function?
              return self.visit_callback(cursor.ruby_name, cursor.find_by_kind(false, :cursor_parameter_decl), cursor.underlying_type.pointee)
            end
        end
        render_cursor(cursor, "typedef_decl")
      end

      def visit_union(cursor)
        return if cursor.forward_declaration?

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

        children = render_children(cursor, indentation: 9, separator: ",\n", strip: true,
                                   exclude_kinds: [:cursor_struct, :cursor_union])

        result << self.render_cursor(cursor, "union", :children => children.lstrip)
        result.join("\n")
      end

      def visit_variable(cursor)
        self.render_cursor(cursor, "variable")
      end

      def figure_method(cursor)
        name = cursor.kind.to_s.delete_prefix("cursor_")
        "visit_#{name.underscore}".to_sym
      end

      def figure_ffi_type(type, context = nil)
        case type.kind
          when :type_bool
            ":bool"
          when :type_double
            ":double"
          when :type_int
            ":int"
          when :type_long
            ":long"
          when :type_longlong
            ":long_long"
          when :type_uint8
            ":uint8"
          when :type_ulong
            ":ulong"
          when :type_ulonglong
            ":ulong_long"
          when :type_uint
            ":uint"
          when :type_ushort
            ":ushort"
          when :type_char_s
            ":char"
          when :type_uchar
            ":uchar"
          when :type_void
            ":void"
          when :type_elaborated
            figure_ffi_elaborated_type(type, context)
          when :type_pointer
            figure_ffi_pointer_type(type, context)
          when :type_enum
            type.declaration.ruby_name
            #match = type.spelling.match(/enum\s*(\S*)$/)
            #match ? match[1].camelize : type.spelling
          when :type_constant_array
            case context
              when :structure
                "[#{figure_ffi_type(type.element_type)}, #{type.size}]"
              else
                ":pointer"
            end
          when :type_incomplete_array
            case type.element_type.kind
              when :type_char_s
                ":string"
              else
                raise("Unsupported incomplete array type: #{type.element_type.kind}")
            end
          else
            raise("Unsupported type: #{type.kind}")
        end
      end

      def figure_ffi_elaborated_type(type, context = nil)
        if type.declaration.spelling == "va_list"
          ":varargs"
        elsif type.canonical.is_a?(::FFI::Clang::Types::Function)
          ":pointer"
        elsif type.canonical.kind == :type_record
          if type.anonymous?
            return type.declaration.anonymous_definer.spelling.camelize
          end

          case
            when context == :function
              "#{type.declaration.ruby_name}.by_value"
            when context == :callback
              "#{type.declaration.ruby_name}.by_value"
            else
              type.declaration.ruby_name
          end
        else
          self.figure_ffi_type(type.canonical, context)
        end
      end

      def figure_ffi_pointer_type(type, context)
        case type.pointee.kind
          when :type_char_s
            context == :callback_return ? ":pointer" : ":string"
          when :type_elaborated
            if type.pointee.canonical.kind == :type_record
              case context
                when :union, :structure, :typedef
                  "#{type.pointee.canonical.declaration.ruby_name}.ptr"
                when :function, :callback, :callback_return
                  "#{type.pointee.canonical.declaration.ruby_name}.by_ref"
                else
                  type.pointee.canonical.declaration.ruby_name
              end
            else
              ":pointer"
            end
          else
            ":pointer"
        end
      end

      def indent(content)
        content.lines.map do |line|
          " " * @indentation + line
        end.join
      end

      def figure_template(cursor)
        name = cursor.kind.to_s.delete_prefix("cursor_")
        File.join(__dir__, "#{name.underscore}.erb")
      end

      def add_indentation(content, indentation)
        content.lines.map do |line|
          if line.strip.empty?
            line
          else
            " " * indentation + line
          end
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

      def render_callback(name, parameter_types, result_type)
        render_template("callback", :ruby => name, :parameter_types => parameter_types,
                        :result_type => result_type)
      end
    end
  end
end