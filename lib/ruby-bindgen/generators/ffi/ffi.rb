module RubyBindgen
  module Generators
    class FFI < Generator
      attr_reader :library_names, :library_versions

      def self.template_dir
        __dir__
      end

      def initialize(inputter, outputter, config)
        super(inputter, outputter, config)
        raise ArgumentError, "FFI format requires the 'project' option" unless @project
        @version_check = config[:version_check]
        @library_names = config[:library_names] || []
        @library_versions = config[:library_versions] || []
        @symbols = RubyBindgen::Symbols.new(config[:symbols] || {})
        raise ArgumentError, "version_check is required when symbols.versions is non-empty" if @symbols.has_versions? && !@version_check
        @library_search_path = config[:library_search_path]
        @export_macros = config[:export_macros] || []
        @module_name = config[:module]
      end

      def generate
        clang_args = @config[:clang_args] || []
        parser = RubyBindgen::Parser.new(@inputter, clang_args, libclang: @config[:libclang])
        symbols_config = @config[:symbols] || {}
        rename_types = RubyBindgen::NameMapper.from_config(symbols_config[:rename_types] || [])
        rename_methods = RubyBindgen::NameMapper.from_config(symbols_config[:rename_methods] || [])
        @namer = RubyBindgen::Namer.new(rename_types, rename_methods)
        ::FFI::Clang::Cursor.namer = @namer
        parser.generate(self)
      end

      # Check if cursor has one of the required export macros in its source text.
      # When export_macros is empty, all symbols pass (no filtering).
      def has_export_macro?(cursor)
        return true if @export_macros.empty?

        source_text = cursor.extent.text
        return false if source_text.nil?
        @export_macros.any? { |macro| source_text.include?(macro) }
      end

      def visit_start
        @generated_files = []
      end

      def visit_translation_unit(translation_unit, path, relative_path)
        basename = File.basename(relative_path, ".*").underscore
        relative_path_2 = File.join(File.dirname(relative_path), "#{basename}.rb")

        cursor = translation_unit.cursor
        module_name = @module_name || cursor.ruby_name
        module_parts = module_name.split("::")

        content = render_children(cursor, indentation: module_parts.length * 2)

        result = render_template("translation_unit",
                                 :module_parts => module_parts,
                                 :content => content.rstrip)

        result.gsub!(/\n\n\n/, "\n\n")
        @generated_files << File.join(File.dirname(relative_path), basename)
        self.outputter.write(relative_path_2, result)
      end

      def visit_end
        create_project_file
      end

      def create_project_file
        return if @generated_files.empty?

        module_name = @module_name || @project.camelize
        module_parts = module_name.split("::")
        depth = module_parts.length
        library = add_indentation(render_template("library"), depth * 2)

        has_versions = @symbols.has_versions?
        version_file = has_versions ? "#{@project}_version" : nil

        content = render_template("project",
                                  :module_parts => module_parts,
                                  :library => library.rstrip,
                                  :version_file => version_file,
                                  :files => @generated_files)

        self.outputter.write("#{@project}_ffi.rb", content)

        create_version_file(module_parts) if version_file
      end

      def create_version_file(module_parts)
        relative_path = "#{@project}_version.rb"
        full_path = self.outputter.output_path(relative_path)
        return if File.exist?(full_path)

        method_name = @version_check
        depth = module_parts.length
        method_body = add_indentation(render_template("version_method", :method_name => method_name), depth * 2)

        content = render_template("version",
                                  :module_parts => module_parts,
                                  :method_body => method_body.rstrip)
        self.outputter.write(relative_path, content)
      end

      def visit_children(cursor, exclude_kinds: Set.new)
        versions = Hash.new { |h, k| h[k] = [] }
        cursor.each(false) do |child_cursor, parent_cursor|
          if child_cursor.location.in_system_header?
            next :continue
          end

          # Note: from_main_file? doesn't work when -include is used, so manually check.
          unless translation_unit_file?(child_cursor)
            next :continue
          end

          # For some reason child.cursor.public? filters out way too much
          if child_cursor.private? || child_cursor.protected?
            next :continue
          end

          if child_cursor.deleted?
            next :continue
          end

          unless child_cursor.declaration? || child_cursor.kind == :cursor_linkage_spec
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
          result << "if #{@version_check} >= #{version}" if version
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

      def visit_enum_decl(cursor)
        return if @symbols.skip?(cursor)

        versions = visit_children(cursor)
        has_versioned_constants = versions.keys.any? { |k| !k.nil? }

        if has_versioned_constants
          render_versioned_enum(cursor, versions)
        else
          children = merge_children(versions, indentation: 2, comma: true, strip: true)
          template = cursor.anonymous? ? "enum_decl_anonymous" : "enum_decl"
          self.render_cursor(cursor, template, :children => children)
        end
      end

      def visit_enum_constant_decl(cursor)
        self.render_cursor(cursor,"enum_constant_decl")
      end

      # extern "C" {} — transparent wrapper, recurse into children
      def visit_linkage_spec(cursor)
        versions = visit_children(cursor)
        merge_children(versions)
      end

      def visit_function(cursor)
        return if cursor.availability == :deprecated
        return if @symbols.skip?(cursor)
        return if references_skipped_type?(cursor.type.result_type)
        return if has_skipped_param_type?(cursor)
        return if has_va_list_param?(cursor)
        return unless has_export_macro?(cursor)

        signature = @symbols.override(cursor)
        if signature
          return self.render_cursor(cursor, "function", :parameter_types => nil, :signature => signature)
        end

        result = Array.new
        parameter_types = cursor.find_by_kind(false, :cursor_parm_decl).map do |parameter|
          callback_name = "#{cursor.spelling.underscore}_#{parameter.spelling.underscore}_callback"
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
        parameter_types << ":varargs" if cursor.type.variadic?
        result << self.render_cursor(cursor, "function", :parameter_types => parameter_types, :signature => nil)
        result.join("\n")
      end

      def visit_struct(cursor)
        return if cursor.forward_declaration?
        return if cursor.opaque_declaration?
        return if @symbols.skip?(cursor)
        return if cursor.anonymous? && !cursor.anonymous_definer

        result = Hash.new { |h, k| h[k] = [] }

        # Define any embedded structures
        cursor.find_by_kind(false, :cursor_struct).each do |struct|
          content = visit_struct(struct)
          next unless content
          version = @symbols.version(struct)
          result[version] << content
        end

        # Define any embedded unions
        cursor.find_by_kind(false, :cursor_union).each do |union|
          content = visit_union(union)
          next unless content
          version = @symbols.version(union)
          result[version] << content
        end

        # Define any embedded callbacks
        cursor.find_by_kind(false, :cursor_field_decl).each do |field|
          if field.type.is_a?(::FFI::Clang::Types::Pointer) && field.type.function?
            callback_name = "#{cursor.spelling.underscore}_#{field.spelling.underscore}_callback"
            parameters = field.find_by_kind(false, :cursor_parm_decl)
            result[nil] << self.visit_callback(callback_name, parameters, field.type.pointee)
          end
        end

        versions = visit_children(cursor, exclude_kinds: [:cursor_struct, :cursor_union])
        has_versioned_fields = versions.keys.any? { |k| !k.nil? }

        if has_versioned_fields
          result[nil] << render_versioned_layout(cursor, versions, "struct")
        else
          children = merge_children(versions, indentation: 9, comma: true, strip: true)
          result[nil] << self.render_cursor(cursor, "struct", :children => children.lstrip)
        end
        merge_children(result)
      end

      def visit_field_decl(cursor)
        ffi_type = if cursor.type.is_a?(::FFI::Clang::Types::Pointer)
                      if cursor.type.function?
                        ":#{cursor.semantic_parent.spelling.underscore}_#{cursor.spelling.underscore}_callback"
                      elsif pointer_to_forward_declaration?(cursor.type)
                       ":pointer"
                      end
                    end

        ffi_type ||= figure_ffi_type(cursor.type, :structure)
        self.render_cursor(cursor, "field_decl", ffi_type: ffi_type)
      end

      def visit_typedef_decl(cursor)
        return if @symbols.skip?(cursor)

        underlying_type = cursor.underlying_type
        canonical_type = underlying_type.canonical

        if [:type_record, :type_enum].include?(canonical_type.kind)
          # Opaque struct/union typedef - emit typedef :pointer
          if canonical_type.declaration.opaque_declaration?
            return render_cursor(cursor, "typedef_decl")
          end
          # Otherwise it's a struct/union/enum we have already rendered - skip
          return
        elsif underlying_type.kind == :type_pointer && underlying_type.function?
          func_type = underlying_type.pointee
          parameter_types = (0...func_type.args_size).map { |i| figure_ffi_type(func_type.arg_type(i), :callback) }
          return render_callback(cursor.ruby_name, parameter_types, func_type.result_type)
        end
        render_cursor(cursor, "typedef_decl")
      end

      def visit_union(cursor)
        return if cursor.forward_declaration?
        return if cursor.opaque_declaration?
        return if @symbols.skip?(cursor)
        return if cursor.anonymous? && !cursor.anonymous_definer

        result = Hash.new { |h, k| h[k] = [] }

        # Define any embedded unions
        cursor.find_by_kind(false, :cursor_union).each do |union|
          content = visit_union(union)
          next unless content
          version = @symbols.version(union)
          result[version] << content
        end

        # Define any embedded structures
        cursor.find_by_kind(false, :cursor_struct).each do |struct|
          content = visit_struct(struct)
          next unless content
          version = @symbols.version(struct)
          result[version] << content
        end

        # Define any embedded callbacks
        cursor.find_by_kind(false, :cursor_field_decl).each do |field|
          if field.type.is_a?(::FFI::Clang::Types::Pointer) && field.type.function?
            callback_name = "#{cursor.spelling.underscore}_#{field.spelling.underscore}_callback"
            parameters = field.find_by_kind(false, :cursor_parm_decl)
            result[nil] << self.visit_callback(callback_name, parameters, field.type.pointee)
          end
        end

        versions = visit_children(cursor, exclude_kinds: [:cursor_struct, :cursor_union])
        has_versioned_fields = versions.keys.any? { |k| !k.nil? }

        if has_versioned_fields
          result[nil] << render_versioned_layout(cursor, versions, "union")
        else
          children = merge_children(versions, indentation: 9, comma: true, strip: true)
          result[nil] << self.render_cursor(cursor, "union", :children => children.lstrip)
        end
        merge_children(result)
      end

      def visit_variable(cursor)
        return if @symbols.skip?(cursor)

        if cursor.type.const_qualified?
          tokens = cursor.translation_unit.tokenize(cursor.extent)
          eq_index = tokens.tokens.index { |t| t.spelling == "=" }
          if eq_index && tokens.tokens[eq_index + 1]&.kind == :literal
            return render_cursor(cursor, "constant",
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

      # Check if any parameter is a va_list type, which cannot be constructed from Ruby.
      # va_list representation varies by platform:
      #   Linux x86_64: elaborated(va_list) -> typedef(__builtin_va_list) -> struct __va_list_tag[1]
      #   Other targets: may use __builtin_va_list, __gnuc_va_list, or other forms
      # The typedef declaration spelling is the most reliable check.
      VA_LIST_NAMES = Set.new(%w[va_list __builtin_va_list __gnuc_va_list]).freeze

      def has_va_list_param?(cursor)
        cursor.find_by_kind(false, :cursor_parm_decl).any? do |param|
          type = param.type
          # Check declaration spelling (works for elaborated and typedef types)
          decl = type.declaration
          next true if decl.kind == :cursor_typedef_decl && VA_LIST_NAMES.include?(decl.spelling)

          # Fallback: check canonical type for __va_list_tag (Linux x86_64 array form)
          canonical = type.canonical
          canonical.kind == :type_constant_array &&
            canonical.element_type.kind == :type_record &&
            canonical.element_type.declaration.spelling == "__va_list_tag"
        end
      end

      # Check if any parameter type of a function references a skipped symbol.
      def has_skipped_param_type?(cursor)
        (0...cursor.type.args_size).any? do |i|
          references_skipped_type?(cursor.type.arg_type(i))
        end
      end

      # Check if a type references a skipped symbol (unwrapping pointers).
      def references_skipped_type?(type)
        type = unwrapped_indirection_type(type)
        decl = type.declaration
        return false if decl.kind == :cursor_no_decl_found
        @symbols.skip?(decl)
      end

      def pointer_to_forward_declaration?(type)
        return false unless type.kind == :type_pointer

        decl = type.pointee.canonical.declaration
        return false if [:cursor_invalid_file, :cursor_no_decl_found].include?(decl.kind)

        decl.opaque_declaration?
      end

      def figure_ffi_type(type, context = nil)
        case type.kind
          when :type_bool
            ":bool"
          when :type_float
            ":float"
          when :type_double
            ":double"
          when :type_int
            ":int"
          when :type_long
            ":long"
          when :type_longlong
            ":long_long"
          when :type_ulong
            ":ulong"
          when :type_ulonglong
            ":ulong_long"
          when :type_uint
            ":uint"
          when :type_short
            ":short"
          when :type_ushort
            ":ushort"
          when :type_char_s
            ":char"
          when :type_uchar, :type_char_u
            ":uchar"
          when :type_schar
            ":int8"
          when :type_wchar
            figure_ffi_type(type.canonical, context)
          when :type_char16
            ":uint16"
          when :type_char32
            ":uint32"
          when :type_longdouble
            ":long_double"
          when :type_int128, :type_uint128
            raise("Unsupported 128-bit integer type: #{type.kind}")
          when :type_void
            ":void"
          when :type_elaborated
            figure_ffi_declared_type(type, context)
          when :type_record
            figure_ffi_record_type(type, context)
          when :type_typedef
            figure_ffi_declared_type(type, context)
          when :type_pointer
            figure_ffi_pointer_type(type, context)
          when :type_enum
            type.declaration.ruby_name
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
          when :type_block_pointer
            # Objective-C block pointers (macOS) — treat as opaque pointer
            ":pointer"
          else
            raise("Unsupported type: #{type.kind}")
        end
      end

      def figure_ffi_declared_type(type, context = nil)
        if type.declaration.spelling == "va_list"
          # va_list cannot be constructed from Ruby — functions with va_list
          # params are skipped in visit_function. Map to :pointer as fallback.
          ":pointer"
        elsif type.canonical.kind == :type_pointer && type.canonical.function?
          # Typedef'd function pointer (callback) — use the callback name
          ":#{type.declaration.ruby_name}"
        elsif type.canonical.kind == :type_function_proto
          ":pointer"
        elsif type.canonical.kind == :type_record
          figure_ffi_record_type(type, context)
        elsif type.canonical.kind == :type_enum
          figure_ffi_type(type.canonical, context)
        else
          spelling = type.declaration.spelling
          if ::FFI::TypeDefs.key?(spelling.to_sym)
            ":#{spelling}"
          else
            self.figure_ffi_type(type.canonical, context)
          end
        end
      end

      def figure_ffi_record_type(type, context = nil)
        if type.canonical.declaration.opaque_declaration?
          return ":pointer"
        end
        if type.anonymous?
          definer = type.declaration.anonymous_definer
          return definer ? definer.spelling.camelize : ":pointer"
        end

        case
          when context == :function
            "#{type.declaration.ruby_name}.by_value"
          when context == :callback
            "#{type.declaration.ruby_name}.by_value"
          else
            type.declaration.ruby_name
        end
      end

      def figure_ffi_pointer_type(type, context)
        case type.pointee.kind
          when :type_char_s
            case context
            when :callback_return
              ":pointer"
            else
              type.pointee.const_qualified? ? ":string" : ":pointer"
            end
          else
            figure_ffi_record_pointer_type(type.pointee, context) || ":pointer"
        end
      end

      def figure_ffi_record_pointer_type(type, context)
        return nil unless type.canonical.kind == :type_record
        return ":pointer" if type.canonical.declaration.opaque_declaration?

        case context
          when :union, :structure, :typedef
            "#{type.canonical.declaration.ruby_name}.ptr"
          when :function, :callback, :callback_return
            "#{type.canonical.declaration.ruby_name}.by_ref"
          else
            type.canonical.declaration.ruby_name
        end
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

      # Render a struct/union with versioned fields as separate definitions per version threshold.
      # Each version gets a complete definition with cumulative fields up to that version.
      # Output is wrapped in if/elsif/else guards.
      def render_versioned_layout(cursor, versions, template)
        # Build sorted version thresholds (nil = unversioned, always included)
        thresholds = versions.keys.compact.sort.reverse

        # Build cumulative field lists: each threshold includes all fields from lower versions
        lines = []
        first = true
        thresholds.each do |threshold|
          guard = first ? "if" : "elsif"
          first = false
          lines << "#{guard} #{@version_check} >= #{threshold}"

          # Collect all fields: unversioned + all versions <= threshold
          cumulative_fields = (versions[nil] || []).dup
          versions.keys.compact.sort.each do |v|
            cumulative_fields.concat(versions[v]) if v <= threshold
          end

          children = cumulative_fields.map(&:rstrip).join(",\n" + " " * 9)
          lines << add_indentation(render_cursor(cursor, template, :children => children).strip, 2)
        end

        # else branch: unversioned fields only (may be empty, but type must still be defined)
        base_fields = versions[nil] || []
        lines << "else"
        children = base_fields.map(&:rstrip).join(",\n" + " " * 9)
        lines << add_indentation(render_cursor(cursor, template, :children => children).strip, 2)
        lines << "end"
        lines.join("\n")
      end

      # Render an enum with versioned constants as separate definitions per version threshold.
      def render_versioned_enum(cursor, versions)
        thresholds = versions.keys.compact.sort.reverse

        lines = []
        first = true
        thresholds.each do |threshold|
          guard = first ? "if" : "elsif"
          first = false
          lines << "#{guard} #{@version_check} >= #{threshold}"

          cumulative = (versions[nil] || []).dup
          versions.keys.compact.sort.each do |v|
            cumulative.concat(versions[v]) if v <= threshold
          end

          children = add_indentation(cumulative.map(&:rstrip).join(",\n"), 2)
          lines << add_indentation(render_cursor(cursor, "enum_decl", :children => children).strip, 2)
        end

        # else branch: unversioned constants only (may be empty, but enum must still be defined)
        base = versions[nil] || []
        lines << "else"
        children = add_indentation(base.map(&:rstrip).join(",\n"), 2)
        lines << add_indentation(render_cursor(cursor, "enum_decl", :children => children).strip, 2)
        lines << "end"
        lines.join("\n")
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
