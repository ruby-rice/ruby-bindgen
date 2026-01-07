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

      def initialize(outputter, project = nil, skip_symbols: [], export_macros: [])
        @project = project&.gsub(/-/, '_')
        @outputter = outputter
        @init_names = Hash.new
        @namespaces = Set.new
        @overloads_stack = Array.new
        @classes = Array.new
        @typedef_map = Hash.new
        @auto_generated_bases = Set.new
        @skip_symbols = skip_symbols
        @export_macros = export_macros
      end

      # Check if a cursor should be skipped based on skip_symbols config.
      # Supports both simple names (e.g., "versionMajor") and fully qualified
      # names (e.g., "cv::ocl::PlatformInfo::versionMajor").
      def skip_symbol?(cursor)
        return true if @skip_symbols.include?(cursor.spelling)

        # Build fully qualified name
        qualified_name = cursor.spelling
        parent = cursor.semantic_parent
        while parent && !parent.kind.nil? && parent.kind != :cursor_translation_unit
          qualified_name = "#{parent.spelling}::#{qualified_name}" if parent.spelling && !parent.spelling.empty?
          parent = parent.semantic_parent
        end

        @skip_symbols.include?(qualified_name)
      end

      def overloads
        @overloads_stack.last || Hash.new
      end

      def visit_start
      end

      def visit_end
        create_project_files
        create_def_file
      end

      def visit_translation_unit(translation_unit, path, relative_path)
        @namespaces.clear
        @classes.clear
        @typedef_map.clear
        @auto_generated_bases.clear

        cursor = translation_unit.cursor
        @overloads_stack.push(cursor.overloads)

        # Build a map from canonical type spellings to typedef/using declarations
        build_typedef_map(cursor)

        # Figure out relative paths for generated header and cpp file
        basename = "#{File.basename(relative_path, ".*")}-rb"
        rice_header = File.join(File.dirname(relative_path), "#{basename}.hpp")
        rice_cpp = File.join(File.dirname(relative_path), "#{basename}.cpp")

        # Track init names
        init_name = "Init_#{File.basename(cursor.spelling, ".*").camelize}"
        @init_names[rice_header] = init_name

        includes = Array.new
        # Get includes. First any includes the source hpp file has
        #includes = translation_unit.includes
        # Then the hpp file
        includes << "#include <#{relative_path}>"
        # Then the rice generated header file
        includes << "#include \"#{File.basename(rice_header)}\""

        class_templates = render_class_templates(cursor)
        content = render_children(cursor, :indentation => 2)

        @overloads_stack.pop

        # Render C++ file
        STDOUT << "  Writing: " << rice_cpp << "\n"
        content = render_cursor(cursor, "translation_unit.cpp",
                                :class_templates => class_templates,
                                :content => content,
                                :includes => includes,
                                :init_name => init_name,
                                :rice_header => rice_header)
        content.gsub!(/\n\n\n/, "\n")
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

        # Do not process deleted constructors
        return if cursor.deleted?

        # Do not process move constructors
        return if cursor.move_constructor?

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
                                         :signature => self.constructor_signature(cursor),
                                         :args => [])

        end

        # Push overloads
        @overloads_stack.push(cursor.overloads)

        # Visit non-static methods first, then static methods.
        # Static methods must come last because Rice uses Ruby's Forwardable module
        # to forward method calls from smart pointers to the wrapped object. To build
        # the list of methods to forward, Rice inspects its native registry which is
        # populated by define_method/define_attr calls. Static factory methods that
        # return smart pointers must therefore be defined after instance methods.
        children += visit_children(cursor,
                                  :exclude_kinds => [:cursor_class_decl, :cursor_struct, :cursor_enum_decl, :cursor_typedef_decl],
                                  :only_static => false)
        children += visit_children(cursor,
                                  :exclude_kinds => [:cursor_class_decl, :cursor_struct, :cursor_enum_decl, :cursor_typedef_decl],
                                  :only_static => true)
        @overloads_stack.pop

        children_content = merge_children(children, :indentation => 2, :separator => ".\n", terminator: ";\n", :strip => true)

        # Render class
        @classes << cursor.cruby_name
        result << self.render_cursor(cursor, "class", :under => under, :base => base,
                                     :children => children_content)

        # Define any embedded classes
        cursor.find_by_kind(false, :cursor_class_decl).each do |child_cursor|
          next if child_cursor.private? || child_cursor.protected?
          result << visit_class_decl(child_cursor)
        end

        # Define any embedded structs
        cursor.find_by_kind(false, :cursor_struct).each do |child_cursor|
          next if child_cursor.private? || child_cursor.protected?
          result << visit_struct(child_cursor)
        end

        # Define any embedded enums
        cursor.find_by_kind(false, :cursor_enum_decl).each do |child_cursor|
          next if child_cursor.private? || child_cursor.protected?
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
        @overloads_stack.push(cursor.overloads)

        # Visit non-static methods first, then static methods.
        # Static methods must come last because Rice uses Ruby's Forwardable module
        # to forward method calls from smart pointers to the wrapped object. To build
        # the list of methods to forward, Rice inspects its native registry which is
        # populated by define_method/define_attr calls. Static factory methods that
        # return smart pointers must therefore be defined after instance methods.
        children = visit_children(cursor,
                                  :exclude_kinds => [:cursor_typedef_decl, :cursor_alias_decl],
                                  :only_static => false)
        children += visit_children(cursor,
                                  :exclude_kinds => [:cursor_typedef_decl, :cursor_alias_decl],
                                  :only_static => true)
        @overloads_stack.pop

        children_content = merge_children(children, :indentation => 4, :separator => ".\n",
                                                    :terminator => ";", :strip => true)

        # Determine containing module
        under = cursor.ancestors_by_kind(:cursor_class_decl, :cursor_struct, :cursor_namespace).first

        # Render class
        result = Array.new
        result << self.render_cursor(cursor, "class_template", :under => under,
                                     :template_signature => template_signature, :children => children_content)

        merge_children(result, indentation: 0, separator: ".\n", strip: false)
      end

      # Check if cursor has one of the required export macros in its source text
      # Used to filter out non-exported functions (e.g., only include CV_EXPORTS functions)
      def has_export_macro?(cursor)
        return true if @export_macros.empty?

        begin
          source_text = cursor.extent.text
          @export_macros.any? { |macro| source_text.include?(macro) }
        rescue => e
          # If we can't read the source, assume it's exported
          true
        end
      end

      # Check if a type is a pointer to an incomplete type (forward declaration)
      # This is common with the pimpl pattern (e.g., Impl* p member or getImpl() method)
      def incomplete_pointer_type?(type)
        return false unless type.kind == :type_pointer

        pointee = type.pointee
        # Check if pointee is an elaborated type pointing to a forward declaration
        if pointee.kind == :type_elaborated || pointee.kind == :type_record
          decl = pointee.declaration
          # Check for opaque declaration (forward declared with no definition in TU)
          return true if decl.respond_to?(:opaque_declaration?) && decl.opaque_declaration?
          # Also check if definition returns an invalid cursor
          if decl.respond_to?(:definition)
            definition = decl.definition
            return true if definition.respond_to?(:invalid?) && definition.invalid?
          end
        end
        false
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
                                elsif type.declaration.kind == :cursor_class_decl
                                  # Template instantiations (e.g., TemplateConstructor<int>) return cursor_class_decl
                                  # Need to preserve template args from type.spelling
                                  spelling = type.spelling
                                  qualified = type.declaration.qualified_name
                                  # Strip const prefix for comparison, re-add if needed
                                  # e.g., "const ocl::Queue" -> "ocl::Queue" for comparison with "cv::ocl::Queue"
                                  const_prefix = type.const_qualified? ? "const " : ""
                                  bare_spelling = spelling.sub(/^const\s+/, '')
                                  # Strip template args for comparison
                                  # e.g., "Internal::Data<2, 2>" -> "Internal::Data"
                                  bare_spelling_no_template = bare_spelling.sub(/<.*/, '')
                                  # If qualified_name ends with bare spelling (sans template), it's more complete
                                  # e.g., spelling="ocl::Queue" qualified="cv::ocl::Queue" -> use qualified
                                  # e.g., spelling="const ocl::Queue" qualified="cv::ocl::Queue" -> use qualified
                                  if qualified.end_with?(bare_spelling_no_template)
                                    # Preserve template args from original spelling
                                    template_args = bare_spelling[/<.*/] || ''
                                    "#{const_prefix}#{qualified}#{template_args}"
                                  else
                                    # Spelling already has full namespace, return as-is
                                    "#{const_prefix}#{bare_spelling}"
                                  end
                                elsif type.declaration.kind == :cursor_typedef_decl && type.declaration.semantic_parent.kind == :cursor_class_template
                                  # Dependent types in templates need 'typename' keyword
                                 "#{type.const_qualified? ? "const " : ""}typename #{type.declaration.semantic_parent.qualified_display_name}::#{type.spelling.sub("const ", "")}"
                                elsif type.declaration.kind == :cursor_typedef_decl
                                  # For typedef inside template instantiation (e.g. std::vector<Pixel>::iterator)
                                  # use type.spelling which preserves template args
                                  spelling = type.spelling
                                  qualified = type.declaration.qualified_name
                                  if spelling.include?('<') && !qualified.include?('<')
                                    "#{type.const_qualified? ? "const " : ""}#{spelling}"
                                  else
                                    "#{type.const_qualified? ? "const " : ""}#{qualified}"
                                  end
                               elsif type.declaration.kind == :cursor_type_alias_decl
                                  # C++11 using declarations (e.g., using SizeArray = std::vector<int>)
                                  # Need to qualify nested type aliases like GpuMatND::SizeArray
                                  spelling = type.spelling
                                  qualified = type.declaration.qualified_name
                                  if qualified.end_with?(spelling)
                                    qualified
                                  elsif spelling.match(/\w+::/)
                                    spelling
                                  else
                                    spelling.sub(type.declaration.spelling, qualified)
                                  end
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
                     # Check if the pointer itself is const (e.g., const char * const)
                     ptr_const = type.const_qualified? ? " const" : ""
                     "#{type_spelling(type.pointee)}*#{ptr_const}"
                   when :type_incomplete_array
                     # This is a parameter like T[]
                     type.canonical.spelling
                   else
                     type.spelling
                 end

        # Horrible hack
        namespace = type.declaration.ancestors_by_kind(:cursor_namespace).first
        if !result.match("::") && namespace
          result = "#{namespace.qualified_name}::#{result}"
        end

        # For template types, check if canonical has better qualified template args
        # e.g., std::vector<Range> vs std::vector<cv::Range>
        # But avoid internal implementation types
        if result.include?('<') && type.canonical.spelling.include?('<')
          canonical = type.canonical.spelling
          # Skip if canonical contains internal implementation types:
          # - libstdc++ uses __gnu_cxx and __normal_iterator
          # - Windows runtime uses _Prefixed names
          unless canonical.match?(/\b_[A-Z]/) || canonical.include?('__gnu_cxx') || canonical.include?('__normal_iterator')
            # If canonical has more :: qualifiers inside template args, prefer it
            result_template_args = result[/(?<=<).*(?=>)/] || ""
            canonical_template_args = canonical[/(?<=<).*(?=>)/] || ""
            if canonical_template_args.count(':') > result_template_args.count(':')
              result = canonical
            end
          end
        end

        result
      end

      def constructor_signature(cursor)
        signature = Array.new

        case cursor.kind
          when :cursor_constructor
            # Use the parent class's qualified_display_name which includes template
            # arguments for template classes (e.g., "cv::Affine3<T>").
            # For non-namespaced templates, qualified_display_name falls back to
            # spelling which loses template args, so use display_name instead.
            parent = cursor.semantic_parent
            class_name = parent.qualified_display_name
            if parent.semantic_parent.kind == :cursor_translation_unit
              class_name = parent.display_name
            end
            signature << class_name
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

          # Check if there is a default value by looking for expression children.
          # The default value is an expression child (cursor_unexposed_expr) of the parameter.
          default_value = find_default_value(param)
          if default_value
            # Use type_spelling to get fully qualified type name
            qualified_type = type_spelling(param.type)
            result << " = static_cast<#{qualified_type}>(#{default_value})"
          end
          result
        end
      end

      # Finds the default value expression for a parameter and returns it with qualified type/function names.
      # For example, transforms "Range::all()" to "cv::Range::all()" and "noArray()" to "cv::noArray()".
      # Returns nil if no default value.
      def find_default_value(param)
        # Default value kinds: complex expressions use cursor_unexposed_expr or cursor_call_expr,
        # simple literals use cursor_integer_literal, etc.
        default_value_kinds = [:cursor_unexposed_expr, :cursor_call_expr] + CURSOR_LITERALS

        # Find the first expression child - this is the default value
        default_expr = param.find_by_kind(false, *default_value_kinds).first
        return nil unless default_expr

        # Get the raw expression text, stripping any leading "= " from the extent
        default_text = default_expr.extent.text.sub(/\A\s*=\s*/, '')

        # Find all type_ref and template_ref cursors within the default expression to qualify type names.
        # Note: We search from default_expr, not param, to avoid the parameter type's type_ref.
        default_expr.find_by_kind(true, :cursor_type_ref, :cursor_template_ref).each do |type_ref|
          ref = type_ref.referenced
          next unless ref && ref.kind != :cursor_invalid_file

          begin
            # For typedefs inside class templates, use qualified_display_name to preserve
            # template parameters (e.g., cv::Affine3<T>::Vec3 instead of cv::Affine3::Vec3)
            qualified_name = if ref.kind == :cursor_typedef_decl && ref.semantic_parent.kind == :cursor_class_template
                               "#{ref.semantic_parent.qualified_display_name}::#{ref.spelling}"
                             else
                               ref.qualified_name
                             end
            extent_text = type_ref.extent.text

            # Only replace if the qualified name is different (has namespace)
            next if extent_text == qualified_name

            # Replace the unqualified type name with the qualified one.
            # Use negative lookbehind to avoid replacing already-qualified names (preceded by ::)
            default_text = default_text.gsub(/(?<!::)\b#{Regexp.escape(extent_text)}\b/, qualified_name)
          rescue ArgumentError
            # Skip if we can't get qualified name
          end
        end

        # Find all decl_ref_expr cursors to qualify function calls and enum values.
        # For example, transforms "noArray()" to "cv::noArray()" and "NORM_L2" to "cv::NORM_L2".
        default_expr.find_by_kind(true, :cursor_decl_ref_expr).each do |decl_ref|
          ref = decl_ref.referenced
          next unless ref && ref.kind != :cursor_invalid_file

          # Skip class methods - they're already qualified by the class name in source.
          # For example, Range::all() has extent "all" but qualified_name "cv::Range::all".
          # We only want to qualify free functions in namespaces, not member functions.
          next if ref.kind == :cursor_cxx_method

          begin
            # For enum constants in unscoped (C-style) enums, the values are in the
            # enclosing namespace, not under the enum type name. So cv::DECOMP_SVD is
            # correct, not cv::DecompTypes::DECOMP_SVD.
            qualified_name = if ref.kind == :cursor_enum_constant_decl &&
                                ref.semantic_parent.kind == :cursor_enum_decl &&
                                !ref.semantic_parent.enum_scoped?
                               # Get the namespace of the enum, then append the constant name
                               enum_namespace = ref.semantic_parent.semantic_parent
                               if enum_namespace && enum_namespace.kind == :cursor_namespace
                                 "#{enum_namespace.qualified_name}::#{ref.spelling}"
                               else
                                 ref.spelling
                               end
                             else
                               ref.qualified_name
                             end
            extent_text = decl_ref.extent.text

            # Only replace if the qualified name is different (has namespace)
            next if extent_text == qualified_name

            # Replace the unqualified name with the qualified one.
            # Use negative lookbehind to avoid replacing already-qualified names (preceded by ::)
            default_text = default_text.gsub(/(?<!::)\b#{Regexp.escape(extent_text)}\b/, qualified_name)
          rescue ArgumentError
            # Skip if we can't get qualified name
          end
        end

        default_text
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

      ITERATOR_METHODS = ["begin", "end", "cbegin", "cend", "rbegin", "rend", "crbegin", "crend"].freeze

      def visit_cxx_method(cursor)
        # Do not process method definitions outside of classes (because we already processed them)
        return if cursor.lexical_parent != cursor.semantic_parent

        # Skip explicitly listed symbols
        return if skip_symbol?(cursor)

        # Skip deprecated methods (they may not be exported from library)
        return if cursor.availability == :deprecated

        # Skip internal methods (underscore suffix naming convention)
        return if cursor.spelling.end_with?('_')

        # Skip methods that return pointers to incomplete types (pimpl pattern)
        # e.g., getImpl() returning Impl* where Impl is forward-declared
        return if incomplete_pointer_type?(cursor.result_type)

        # Is this an iterator?
        if ITERATOR_METHODS.include?(cursor.spelling)
          return visit_cxx_iterator_method(cursor)
        end

        signature = if self.overloads.include?(cursor.spelling)
                      method_signature(cursor)
                    else
                      nil
                    end

        result = Array.new

        name = cursor.ruby_name
        args = arguments(cursor)

        is_template = cursor.semantic_parent.kind == :cursor_class_template
        result << self.render_cursor(cursor, "cxx_method",
                                     :name => name,
                                     :is_template => is_template,
                                     :signature => signature,
                                     :args => args)

        # Special handling for implementing #[](index, value)
        if cursor.spelling == "operator[]" && cursor.result_type.kind == :type_lvalue_ref &&
           !cursor.result_type.non_reference_type.const_qualified? && !cursor.const?
          result << self.render_cursor(cursor, "operator[]",
                                       :name => name)
        end
        result
      end

      # Generates Rice define_iterator calls for C++ iterator methods.
      # In C++, cbegin/crbegin can be called on non-const objects but return const iterators,
      # while begin/rbegin const can only be called on const objects. In Ruby this distinction
      # doesn't exist, so we skip cbegin/crbegin to avoid generating duplicate "each_const"
      # and "each_reverse_const" methods.
      def visit_cxx_iterator_method(cursor)
        iterator_name = case cursor.spelling
                          when "begin"
                            cursor.const? ? "each_const" : "each"
                          when "cbegin"
                            return
                          when "rbegin"
                            cursor.const? ? "each_reverse_const" : "each_reverse"
                          when "crbegin"
                            return
                          else
                            # We don't care about end methods (end, cend, rend, crend)
                            return
                        end

        begin_method = cursor.spelling
        end_method = begin_method.sub("begin", "end")
        signature = method_signature(cursor)
        is_template = cursor.semantic_parent.kind == :cursor_class_template

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

        result_type = cursor.type.result_type

        # Skip "safe bool idiom" conversion operators from pre-C++11.
        # These are typedefs to member function pointers used before explicit operator bool().
        # Pattern: typedef void (Class::*bool_type)() const; operator bool_type() const;
        if result_type.declaration.kind == :cursor_typedef_decl
          canonical = result_type.canonical
          if canonical.kind == :type_member_pointer
            # Check if the pointee is a function type
            pointee = canonical.pointee
            if pointee.kind == :type_function_proto || pointee.kind == :type_function_no_proto
              return
            end
          end
        end

        result_type_spelling = type_spelling(result_type)
        is_const = cursor.const?

        # For class templates, the result type may contain "type-parameter-X_Y" which
        # generates invalid Ruby method names. Use generic names instead.
        if cursor.semantic_parent.kind == :cursor_class_template &&
           result_type.canonical.spelling.include?("type-parameter-")
          # Determine if this is a pointer conversion
          if result_type.kind == :type_pointer
            ruby_name = is_const ? "to_const_ptr" : "to_ptr"
          else
            # Skip other template parameter conversions for now
            return
          end
        else
          ruby_name = cursor.ruby_name
        end

        self.render_cursor(cursor, "conversion_function",
                           :ruby_name => ruby_name, :result_type => result_type_spelling,
                           :is_const => is_const)
      end

      def visit_enum_decl(cursor)
        return if CURSOR_CLASSES.include?(cursor.semantic_parent.kind) && !cursor.public?
        if cursor.anonymous? && cursor.semantic_parent.kind == :cursor_class_template
          indentation = 0
          separator = ".\n"
          terminator = ""
        elsif cursor.anonymous?
          indentation = 0
          separator = ";\n"
          terminator = ";\n"
        else
          indentation = 2
          separator = ".\n"
          terminator = ";\n"
        end

        under = cursor.ancestors_by_kind(:cursor_class_decl, :cursor_struct, :cursor_namespace).first
        children = render_children(cursor, indentation: indentation, separator: separator, terminator: terminator, strip: true)
        self.render_cursor(cursor, "enum_decl", :under => under, :children => children)
      end

      def visit_enum_constant_decl(cursor)
        self.render_cursor(cursor, "enum_constant_decl")
      end

      def visit_function(cursor)
        # Can't return arrays in C++
        return if cursor.type.result_type.is_a?(::FFI::Clang::Types::Array)

        # Skip explicitly listed symbols
        return if skip_symbol?(cursor)

        # Skip functions without required export macros (e.g., CV_EXPORTS)
        return unless has_export_macro?(cursor)

        # Skip deprecated functions (they may not be exported from library)
        return if cursor.availability == :deprecated

        # Skip internal functions (underscore suffix naming convention)
        return if cursor.spelling.end_with?('_')

        if cursor.spelling.match(/operator/)
          return self.visit_operator_non_member(cursor)
        end

        name = cursor.ruby_name
        args = arguments(cursor)

        signature = if self.overloads.include?(cursor.spelling)
                      method_signature(cursor)
                    else
                      nil
                    end

        under = cursor.ancestors_by_kind(:cursor_namespace).first
        self.render_cursor(cursor, "function",
                           :under => under,
                           :name => name,
                           :signature => signature,
                           :args => args)
      end

      def visit_macro_definition(cursor)
        tokens = cursor.translation_unit.tokenize(cursor.extent)
        return unless tokens.size == 2
        return unless tokens.tokens[0].kind == :identifier
        return unless tokens.tokens[1].kind == :literal

        self.render_cursor(cursor, "constant",
                           :name => tokens.tokens[0].spelling.upcase_first,
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

        @overloads_stack.push(cursor.overloads)
        result << self.render_children(cursor)
        @overloads_stack.pop

        result.join("\n")
      end

      def visit_field_decl(cursor)
        return unless cursor.public?

        # Can't return arrays in C++
        return if cursor.type.is_a?(::FFI::Clang::Types::Array)

        # Skip fields that are pointers to incomplete types (pimpl pattern)
        # e.g., Impl* p member where Impl is forward-declared
        return if incomplete_pointer_type?(cursor.type)

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
        # Rice already provides bitwise operators (&, |, ^, ~, <<, >>) for enums automatically
        return if class_cursor.kind == :cursor_enum_decl

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

        # Skip if already processed (can happen when force-generating base classes)
        return if @classes.include?(cursor.cruby_name)

        # Skip typedefs to std:: types - Rice handles these automatically
        canonical = cursor.underlying_type.canonical.spelling
        return if canonical.start_with?("std::")

        cursor_template_ref = cursor.find_by_kind(false, :cursor_template_ref).first

        # Handle template case. For example:
        #   typedef Point_<int> Point2i;
        if cursor_template_ref
          visit_template_specialization(cursor, cursor_template_ref.referenced, cursor.underlying_type)
        else
          # Check for reference to template reference. For example:
          #   typedef Point2i Point;
          cursor_ref = cursor.find_by_kind(false, :cursor_type_ref).first
          if cursor_ref
            cursor_template_ref = cursor_ref.referenced.find_by_kind(false, :cursor_template_ref).first
            if cursor_template_ref
              visit_template_specialization(cursor, cursor_template_ref.referenced, cursor_ref.referenced.underlying_type)
            end
          end
        end
      end

      # Handle C++11 'using' type alias declarations the same as typedef
      def visit_type_alias_decl(cursor)
        visit_typedef_decl(cursor)
      end

      def visit_template_specialization(cursor, cursor_template, underlying_type)
        under = cursor.ancestors_by_kind(:cursor_class_decl, :cursor_struct, :cursor_namespace).first
        template_arguments = underlying_type.canonical.spelling.match(/\<(.*)\>/)[1]

        result = ""

        # Is there a base class?
        base_ref = cursor_template.find_by_kind(false, :cursor_cxx_base_specifier).first
        base_spelling = nil
        if base_ref
          # Base class children can be a :cursor_type_ref or :cursor_template_ref
          type_ref = base_ref.find_by_kind(false, :cursor_type_ref, :cursor_template_ref).first
          base = type_ref.definition

          # Resolve the base class to its instantiated form (e.g., PtrStep<unsigned char>)
          base_spelling = resolve_base_instantiation(cursor, underlying_type)

          # Ensure the base class is generated before this class
          if base_spelling
            base_typedef = @typedef_map[base_spelling]
            if base_typedef
              # Base has a typedef - check if it has been generated yet
              unless @classes.include?(base_typedef.cruby_name)
                # Force generate the typedef first (recursively handles its bases)
                result = visit_typedef_decl(base_typedef)
              end
            elsif !@auto_generated_bases.include?(base_spelling)
              # No typedef - auto-generate
              result = auto_generate_base_class(base_ref, base_spelling, template_arguments, under)
            end
          end
        end

        template_specialization = type_spelling(underlying_type)

        @classes << cursor.cruby_name
        result + self.render_cursor(cursor, "class_template_specialization",
                           :cursor_template => cursor_template,
                           :template_specialization => template_specialization,
                           :template_arguments => template_arguments,
                           :base_ref => base_ref,
                           :base => base,
                           :base_spelling => base_spelling,
                           :under => under)
      end

      # Auto-generate a base class definition when no typedef exists for it
      def auto_generate_base_class(base_ref, base_spelling, template_arguments, under)
        # Get the base template cursor
        base_template_ref = base_ref.find_by_kind(false, :cursor_template_ref).first
        return "" unless base_template_ref

        base_template = base_template_ref.referenced

        result = ""

        # Check if this base class has its own base that needs auto-generation (recursive)
        base_base_ref = base_template.find_by_kind(false, :cursor_cxx_base_specifier).first
        base_base_spelling = nil
        if base_base_ref
          base_base_template_ref = base_base_ref.find_by_kind(false, :cursor_template_ref).first
          if base_base_template_ref
            # Get namespace from base_spelling
            namespace = base_spelling.split("<").first.split("::")[0..-2].join("::")
            base_base_name = base_base_template_ref.referenced.spelling
            base_base_spelling = namespace.empty? ? "#{base_base_name}<#{template_arguments}>" : "#{namespace}::#{base_base_name}<#{template_arguments}>"

            # Recursively auto-generate if needed
            if !@typedef_map[base_base_spelling] && !@auto_generated_bases.include?(base_base_spelling)
              result = auto_generate_base_class(base_base_ref, base_base_spelling, template_arguments, under)
            end
          end
        end

        # Mark as generated to avoid duplicates
        @auto_generated_bases << base_spelling

        # Generate a Ruby class name from the base spelling
        ruby_name = base_spelling.split("::").last.gsub(/<.*>/, "").camelize +
                    template_arguments.split(",").map(&:strip).map { |t| t.gsub(/[^a-zA-Z0-9]/, " ").split.map(&:capitalize).join }.join

        cruby_name = "rb_c#{ruby_name}"

        @classes << cruby_name
        result + render_template("auto_generated_base_class",
                        :cruby_name => cruby_name,
                        :ruby_name => ruby_name,
                        :base_spelling => base_spelling,
                        :base_base_spelling => base_base_spelling,
                        :base_template => base_template,
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

        # Skip compiler/cuda keywords like __device__ __forceinline__
        return if cursor.spelling.match(/^__.*__$/)

        # Const variables become Ruby constants
        if cursor.type.const_qualified?
          visit_variable_constant(cursor)
        else
          parent_kind = cursor.semantic_parent.kind
          if parent_kind == :cursor_translation_unit || parent_kind == :cursor_namespace
            # Non-const variables at global/namespace scope become Ruby constants
            # Rice's define_singleton_attr only works on Data_Type<T>, not Class or Module
            visit_variable_constant(cursor)
          else
            # Static class fields use define_singleton_attr on Data_Type<T>
            self.render_cursor(cursor, "variable")
          end
        end
      end

      def visit_variable_constant(cursor)
        self.render_cursor(cursor, "constant",
                           :name => cursor.spelling.upcase_first,
                           :qualified_name => cursor.qualified_display_name)
      end

      def create_project_files
        return unless @project

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
        return unless @project

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

          # Skip forward declarations
          if class_template_cursor.declaration? && !class_template_cursor.definition?
            next :continue
          end
          if class_template_cursor.location.in_system_header?
            next :continue
          end

          unless class_template_cursor.location.from_main_file?
            next :continue
          end

          @overloads_stack.push(cursor.overloads)
          results << visit_class_template_builder(class_template_cursor)
          @overloads_stack.pop
        end
        result = merge_children(results, :indentation => indentation, :separator => separator, :strip => strip)
      end

      def visit_children(cursor, exclude_kinds: Set.new, only_static: nil)
        results = Array.new
        cursor.each(false) do |child_cursor, parent_cursor|
          if child_cursor.location.in_system_header?
            next :continue
					end

					path = child_cursor.location

					# This sometimes does not work - for example OpenCV defines the macros
					# CV__DNN_INLINE_NS_BEGIN/CV__DNN_INLINE_NS_END in a separate header file
					# which causes from_main_file? to be false. So manually check.
					# unless child_cursor.location.from_main_file?
					unless child_cursor.file_location.file == child_cursor.translation_unit.file.name
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

          # Filter by static if requested
          # Non-methods are only visited when only_static is false (first pass)
          # Methods are filtered by their static status
          if !only_static.nil?
            if child_cursor.kind == :cursor_cxx_method
              next :continue if only_static != child_cursor.static?
            else
              # Non-methods only in the non-static pass
              next :continue if only_static
            end
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
        children = visit_children(cursor)
        merge_children(children, indentation: indentation, separator: separator, terminator: terminator, strip: strip)
      end

      # Build a map from canonical type spellings to typedef/using declarations.
      # This allows us to look up if a typedef exists for a given template instantiation.
      def build_typedef_map(cursor)
        cursor.each(true) do |child, parent|
          # Handle both typedef and using statements
          next unless [:cursor_typedef_decl, :cursor_type_alias_decl].include?(child.kind)
          next unless child.location.from_main_file?

          canonical = child.underlying_type.canonical.spelling
          @typedef_map[canonical] = child
        end
      end

      # Given a typedef cursor and its underlying type, resolve the base class
      # to an actual instantiated type (e.g., PtrStep<unsigned char> instead of PtrStep<T>).
      # Returns the resolved base class spelling or nil if no base class exists.
      def resolve_base_instantiation(cursor, underlying_type)
        # Get template reference from the typedef
        template_ref = cursor.find_by_kind(false, :cursor_template_ref).first
        return nil unless template_ref

        # Get base specifier from the template
        base_spec = template_ref.referenced.find_by_kind(false, :cursor_cxx_base_specifier).first
        return nil unless base_spec

        # Get the template reference in the base specifier
        base_template_ref = base_spec.find_by_kind(false, :cursor_template_ref).first
        return nil unless base_template_ref

        # Extract template arguments from the canonical spelling
        canonical = underlying_type.canonical.spelling
        return nil unless canonical =~ /<(.+)>\z/

        template_args = $1
        # Get namespace from canonical (everything before the last ::Name<args>)
        namespace = canonical.split('<').first.split('::')[0..-2].join('::')

        # Construct the fully qualified base class instantiation
        base_name = base_template_ref.referenced.spelling
        if namespace.empty?
          "#{base_name}<#{template_args}>"
        else
          "#{namespace}::#{base_name}<#{template_args}>"
        end
      end
    end
  end
end