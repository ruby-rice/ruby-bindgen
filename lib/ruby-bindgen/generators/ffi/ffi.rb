module RubyBindgen
  module Generators
    class FFI < Generator
      attr_reader :library_names, :library_versions

      def self.template_dir
        __dir__
      end

      def initialize(inputter, outputter, config)
        super(inputter, outputter, config)
        @library_names = config[:library_names] || []
        @library_versions = config[:library_versions] || []
        @symbols = RubyBindgen::Symbols.new(config[:symbols] || {})
        @version_macro = config[:version_macro]
        @export_macros = config[:export_macros] || []
        @indentation = 0
      end

      def generate
        clang_args = @config[:clang_args] || []
        parser = RubyBindgen::Parser.new(@inputter, clang_args, libclang: @config[:libclang])
        parser.generate(self)
      end

      # Check if cursor has one of the required export macros in its source text.
      # When export_macros is empty, all symbols pass (no filtering).
      def has_export_macro?(cursor)
        return true if @export_macros.empty?

        begin
          source_text = cursor.extent.text
          return true if source_text.nil?
          @export_macros.any? { |macro| source_text.include?(macro) }
        rescue
          true
        end
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
        versions = Hash.new { |h, k| h[k] = [] }
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
            version = @symbols.version(child_cursor)
            case content
              when Array
                versions[version] += content
              when String
                versions[version] << content
            end
          end
          next :continue
        end
        versions
      end

      def merge_children(versions, indentation: 0, comma: false, strip: false)
        lines = versions.keys.sort_by { |key| key.to_s }.each_with_object([]) do |version, result|
          next unless versions[version]&.any?
          result << "if #{@version_macro} >= #{version}" if version
          versions[version].each do |line|
            line = line.rstrip if strip
            line = add_indentation(line, 2) if version
            result << line
          end
          result << "end" if version
        end

        return "" if lines.empty?

        separator = comma ? ",\n" : "\n"
        result = lines.join(separator)
        result = add_indentation(result, indentation) if indentation > 0
        result
      end

      def render_children(cursor, indentation: 0, comma: false, strip: false, exclude_kinds: Set.new)
        versions = visit_children(cursor, exclude_kinds: exclude_kinds)
        merge_children(versions, indentation: indentation, comma: comma, strip: strip)
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

      def visit_macro_definition(cursor)
        tokens = cursor.translation_unit.tokenize(cursor.extent)
        return unless tokens.size == 2
        return unless tokens.tokens[0].kind == :identifier
        return unless tokens.tokens[1].kind == :literal

        self.render_cursor(cursor, "macro_definition",
                           :name => tokens.tokens[0].spelling,
                           :value => tokens.tokens[1].spelling)
      end

      def visit_enum_decl(cursor)
        return if @symbols.skip?(cursor)

        children = render_children(cursor, indentation: 2, comma: true, strip: true)
        self.render_cursor(cursor, "enum_decl", :children => children)
      end

      def visit_enum_constant_decl(cursor)
        self.render_cursor(cursor,"enum_constant_decl")
      end

      def visit_function(cursor)
        return if @symbols.skip?(cursor)
        return unless has_export_macro?(cursor)

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
        return if @symbols.skip?(cursor)

        result = Hash.new { |h, k| h[k] = [] }

        # Define any embedded structures
        cursor.find_by_kind(false, :cursor_struct).each do |struct|
          version = @symbols.version(struct)
          result[version] << visit_struct(struct)
        end

        # Define any embedded unions
        cursor.find_by_kind(false, :cursor_union).each do |union|
          version = @symbols.version(union)
          result[version] << visit_union(union)
        end

        # Define any embedded callbacks
        cursor.find_by_kind(false, :cursor_field_decl).each do |field|
          if field.type.is_a?(::FFI::Clang::Types::Pointer) && field.type.function?
            callback_name = "#{cursor.spelling}_#{field.spelling}_callback"
            parameters = field.find_by_kind(false, :cursor_parm_decl)
            result[nil] << self.visit_callback(callback_name, parameters, field.type.pointee)
          end
        end

        children = render_children(cursor, indentation: 9, comma: true, strip: true,
                                           exclude_kinds: [:cursor_struct, :cursor_union])

        result[nil] << self.render_cursor(cursor, "struct", :children => children.lstrip)
        merge_children(result)
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
        return if @symbols.skip?(cursor)

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
        return if @symbols.skip?(cursor)

        result = Hash.new { |h, k| h[k] = [] }

        # Define any embedded unions
        cursor.find_by_kind(false, :cursor_union).each do |struct|
          version = @symbols.version(struct)
          result[version] << visit_struct(struct)
        end

        # Define any embedded structures
        cursor.find_by_kind(false, :cursor_struct).each do |struct|
          version = @symbols.version(struct)
          result[version] << visit_struct(struct)
        end

        # Define any embedded callbacks
        cursor.find_by_kind(false, :cursor_field_decl).each do |field|
          if field.type.is_a?(::FFI::Clang::Types::Pointer) && field.type.function?
            callback_name = "#{cursor.ruby}_#{field.ruby}_callback"
            result[nil] << self.visit_callback(callback_name, field.parameters, field.type.pointee)
          end
        end

        children = render_children(cursor, indentation: 9, comma: true, strip: true,
                                   exclude_kinds: [:cursor_struct, :cursor_union])

        result[nil] << self.render_cursor(cursor, "union", :children => children.lstrip)
        merge_children(result)
      end

      def visit_variable(cursor)
        return if @symbols.skip?(cursor)

        if cursor.type.const_qualified?
          tokens = cursor.translation_unit.tokenize(cursor.extent)
          eq_index = tokens.tokens.index { |t| t.spelling == "=" }
          if eq_index && tokens.tokens[eq_index + 1]&.kind == :literal
            return render_cursor(cursor, "macro_definition",
                                 name: cursor.ruby_name,
                                 value: tokens.tokens[eq_index + 1].spelling)
          end
        end

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

      def render_callback(name, parameter_types, result_type)
        render_template("callback", :ruby => name, :parameter_types => parameter_types,
                        :result_type => result_type)
      end
    end
  end
end