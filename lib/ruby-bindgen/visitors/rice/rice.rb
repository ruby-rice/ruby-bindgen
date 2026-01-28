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

      # Fundamental types that should use ArgBuffer/ReturnBuffer when passed/returned as pointers
      FUNDAMENTAL_TYPES = [
        :type_void, :type_bool,
        :type_char_u, :type_uchar, :type_char16, :type_char32, :type_char_s,
        :type_schar, :type_wchar,
        :type_short, :type_ushort,
        :type_int, :type_uint,
        :type_long, :type_ulong,
        :type_longlong, :type_ulonglong,
        :type_int128, :type_uint128,
        :type_float, :type_double, :type_longdouble,
        :type_float128, :type_float16,
        :type_nullptr
      ].freeze

      attr_reader :project, :outputter

      def initialize(outputter, project = nil, skip_symbols: [], export_macros: [], include_header: nil)
        @project = project&.gsub(/-/, '_')
        @outputter = outputter
        @include_header = include_header
        @init_names = Hash.new
        @namespaces = Set.new
        @overloads_stack = Array.new
        @classes = Hash.new  # Maps cruby_name -> C++ type for Data_Type<T> declarations
        @typedef_map = Hash.new
        @type_name_map = Hash.new  # Maps simple type names to qualified names
        @auto_generated_bases = Set.new
        @skip_symbols = skip_symbols
        @export_macros = export_macros
        # Non-member operators grouped by target class cruby_name
        @non_member_operators = Hash.new { |h, k| h[k] = [] }
        # Iterators that need std::iterator_traits specialization
        @incomplete_iterators = Hash.new
        # Template classes with no bindable content (all methods deprecated/skipped)
        @empty_builders = Set.new
      end

      # Check if a cursor should be skipped based on skip_symbols config.
      # Supports simple names, fully qualified names, and regex patterns (strings starting with /).
      # Examples:
      #   - "versionMajor" - matches method name
      #   - "cv::ocl::PlatformInfo::versionMajor" - matches fully qualified name
      #   - "/cv::dnn::.*::Layer::init.*/" - regex pattern
      def skip_symbol?(cursor)
        # Build fully qualified name
        qualified_name = cursor.spelling
        parent = cursor.semantic_parent
        while parent && !parent.kind.nil? && parent.kind != :cursor_translation_unit
          qualified_name = "#{parent.spelling}::#{qualified_name}" if parent.spelling && !parent.spelling.empty?
          parent = parent.semantic_parent
        end

        @skip_symbols.any? do |skip|
          if skip.start_with?('/') && skip.end_with?('/')
            # Regex pattern
            pattern = Regexp.new(skip[1..-2])
            pattern.match?(cursor.spelling) || pattern.match?(qualified_name)
          else
            # Exact match or prefix match
            cursor.spelling == skip ||
            qualified_name == skip ||
            qualified_name.start_with?("#{skip}<") ||
            qualified_name.start_with?("#{skip}::")
          end
        end
      end

      def overloads
        @overloads_stack.last || Hash.new
      end

      # Visit class children, ensuring static methods come last.
      # Rice's Forwardable module needs instance methods registered before
      # static factory methods that return smart pointers.
      # Visit children in two passes: non-static first, then static.
      # Static methods must come last because Rice's Forwardable module needs
      # instance methods registered before static factory methods that return smart pointers.
      def visit_children_two_pass(cursor, exclude_kinds:)
        @overloads_stack.push(cursor.overloads)
        children = visit_children(cursor, exclude_kinds: exclude_kinds, only_static: false)
        children += visit_children(cursor, exclude_kinds: exclude_kinds, only_static: true)
        @overloads_stack.pop
        children
      end

      def visit_start
      end

      def visit_end
        create_rice_include_header
        create_project_files
        create_def_file
      end

      # Returns the path to the Rice include header (user-specified or auto-generated)
      def rice_include_header
        @include_header || "#{@project || 'rice'}_include.hpp"
      end

      # Generate default Rice include header if user didn't specify one
      def create_rice_include_header
        return if @include_header  # User specified their own header

        header_path = rice_include_header
        STDOUT << "  Writing: " << header_path << "\n"
        content = render_template("rice_include.hpp")
        self.outputter.write(header_path, content)
      end

      def visit_translation_unit(translation_unit, path, relative_path)
        @namespaces.clear
        @classes.clear
        @typedef_map.clear
        @type_name_map.clear
        @auto_generated_bases.clear
        @non_member_operators.clear
        @incomplete_iterators.clear

        cursor = translation_unit.cursor
        @overloads_stack.push(cursor.overloads)

        # Build maps for type lookups
        build_typedef_map(cursor)
        build_type_name_map(cursor)

        # Figure out relative paths for generated header and cpp file
        basename = "#{File.basename(relative_path, ".*")}-rb"
        rice_header = File.join(File.dirname(relative_path), "#{basename}.hpp")
        rice_cpp = File.join(File.dirname(relative_path), "#{basename}.cpp")

        # Track init names - use relative path to avoid conflicts (e.g., core/version vs dnn/version)
        path_parts = Pathname.new(relative_path).each_filename.to_a
        path_parts.shift if path_parts.length >= 2  # Remove top-level directory (e.g., opencv2)
        filename = Pathname.new(path_parts.pop).sub_ext('').to_s.camelize
        dir_part = path_parts.map(&:camelize).join('_')
        init_name = dir_part.empty? ? "Init_#{filename}" : "Init_#{dir_part}_#{filename}"
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

        # Render non-member operators grouped by class
        non_member_ops = render_non_member_operators
        unless non_member_ops.empty?
          content = content + "\n  " + non_member_ops
        end

        @overloads_stack.pop

        # Render C++ file
        STDOUT << "  Writing: " << rice_cpp << "\n"
        content = render_cursor(cursor, "translation_unit.cpp",
                                :class_templates => class_templates,
                                :content => content,
                                :includes => includes,
                                :init_name => init_name,
                                :rice_header => rice_header,
                                :incomplete_iterators => @incomplete_iterators)
        content = cleanup_whitespace(content)
        self.outputter.write(rice_cpp, content)

        # Render header file
        STDOUT << "  Writing: " << rice_header << "\n"
        # Compute relative path from translation unit directory to the include header
        tu_dir = Pathname.new(File.dirname(rice_header))
        include_path = Pathname.new(rice_include_header)
        relative_include = include_path.relative_path_from(tu_dir).to_s
        content = render_cursor(cursor, "translation_unit.hpp",
                                :init_name => init_name,
                                :rice_include_header => relative_include)
        self.outputter.write(rice_header, content)
      end

      def visit_constructor(cursor)
        # Do not process class constructors defined outside of the class definition
        return if cursor.lexical_parent != cursor.semantic_parent

        # Do not process deleted constructors
        return if cursor.deleted?

        # Skip deprecated constructors (they may not be exported from library)
        return if cursor.availability == :deprecated

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
        # Skip explicitly listed symbols
        return if skip_symbol?(cursor)

        result = Array.new

        # Determine containing module
        under = cursor.ancestors_by_kind(:cursor_class_decl, :cursor_struct, :cursor_namespace).first

        # Is there a base class?
        base = nil
        auto_generated_base = ""
        base_specifier = cursor.find_by_kind(false, :cursor_cxx_base_specifier).first
        if base_specifier
          # Use canonical spelling for fully qualified type name with namespaces
          base = base_specifier.type.canonical.spelling

          # Check if base is a template instantiation that needs to be auto-generated
          if base.include?('<') && !@auto_generated_bases.include?(base)
            auto_generated_base = auto_generate_template_base_for_class(base_specifier, base, under)
          end
        end

        # Visit children
        children = Array.new

        # Are there any constructors? If not, C++ will define one implicitly
        # (but not for incomplete/opaque types which can't be instantiated)
        constructors = cursor.find_by_kind(false, :cursor_constructor)
        if !cursor.abstract? && !cursor.opaque_declaration? && constructors.empty?
          children << self.render_template("constructor",
                                         :cursor => cursor,
                                         :signature => self.constructor_signature(cursor),
                                         :args => [])

        end

        children += visit_children_two_pass(cursor,
                                           exclude_kinds: [:cursor_class_decl, :cursor_struct, :cursor_enum_decl, :cursor_typedef_decl])

        children_content = merge_children(children, :indentation => 2, :separator => ".\n", terminator: ";\n", :strip => true)

        # Collect forward-declared (incomplete) inner classes
        # They must be registered with Rice before the parent class methods use them
        incomplete_classes = []
        cursor.find_by_kind(false, :cursor_class_decl, :cursor_struct).each do |child_cursor|
          next if child_cursor.private? || child_cursor.protected?
          next unless child_cursor.opaque_declaration?
          incomplete_classes << visit_incomplete_class(child_cursor, cursor)
        end
        incomplete_classes_content = merge_children(incomplete_classes, :separator => "\n")

        # Auto-instantiate any class templates used as parameter types
        auto_instantiated = auto_instantiate_parameter_templates(cursor, under)
        result << auto_instantiated unless auto_instantiated.empty?

        # Render class
        @classes[cursor.cruby_name] = qualified_class_name_cpp(cursor)
        result << self.render_cursor(cursor, "class", :under => under, :base => base,
                                     :auto_generated_base => auto_generated_base,
                                     :incomplete_classes => incomplete_classes_content,
                                     :children => children_content)

        # Define any complete embedded classes and structs
        cursor.find_by_kind(false, :cursor_class_decl, :cursor_struct).each do |child_cursor|
          next if child_cursor.private? || child_cursor.protected?
          next if child_cursor.opaque_declaration?
          result << visit_class_decl(child_cursor)
        end

        # Define any embedded enums
        cursor.find_by_kind(false, :cursor_enum_decl).each do |child_cursor|
          next if child_cursor.private? || child_cursor.protected?
          result << visit_enum_decl(child_cursor)
        end

        merge_children(result)
      end
      alias :visit_struct :visit_class_decl

      # Scan a class's methods for class template parameters that need auto-instantiation.
      def auto_instantiate_parameter_templates(cursor, under)
        result = []

        cursor.each(false) do |child, _|
          next unless [:cursor_cxx_method, :cursor_constructor].include?(child.kind)
          next if child.private? || child.protected?

          child.find_by_kind(false, :cursor_parm_decl).each do |param|
            # Unwrap reference and pointer types
            type = param.type
            type = type.non_reference_type while type.kind == :type_lvalue_ref || type.kind == :type_rvalue_ref
            type = type.pointee while type.kind == :type_pointer

            # Skip if not a template instantiation or is std::
            next unless type.num_template_arguments > 0
            next if type.canonical.spelling.start_with?("std::")

            # Find class template declaration
            template_ref = param.find_by_kind(true, :cursor_template_ref).first
            next unless template_ref
            decl = template_ref.referenced
            next unless decl.kind == :cursor_class_template
            next unless (decl.location.file == cursor.location.file rescue false)

            # Auto-instantiate if no typedef exists
            instantiated_type = type_spelling(type).sub(/^const\s+/, '')
            next if @typedef_map[instantiated_type]

            code = auto_instantiate_template(decl, instantiated_type, under)
            result << code unless code.empty?
          end
        end

        merge_children(result, :separator => "\n")
      end

      # Visit a forward-declared (incomplete) inner class.
      # These need to be registered with Rice so that types like Ptr<Impl> work.
      # Must be registered BEFORE the parent class methods that use them (smart pointer issue).
      def visit_incomplete_class(cursor, parent_cursor)
        # Skip if already defined
        return "" if @classes.key?(cursor.cruby_name)

        @classes[cursor.cruby_name] = cursor.qualified_name
        render_cursor(cursor, "incomplete_class", :under => parent_cursor)
      end

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

        children = visit_children_two_pass(cursor,
                                           exclude_kinds: [:cursor_typedef_decl, :cursor_alias_decl])

        # If no children (all methods deprecated/skipped), don't generate builder
        if children.empty?
          @empty_builders.add(cursor.spelling)
          return ""
        end

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
          return true if source_text.nil?
          @export_macros.any? { |macro| source_text.include?(macro) }
        rescue
          # If we can't read the source, assume it's exported
          true
        end
      end

      # Check if a type is copyable (has an accessible copy constructor).
      # Returns false if the copy constructor is private (C++03 idiom) or deleted (C++11).
      # This is used to determine if we can generate default values for parameters -
      # Rice's Arg mechanism needs to copy the default value internally.
      def copyable_type?(type)
        # Strip references to get to the actual type
        type = type.non_reference_type while type.kind == :type_lvalue_ref || type.kind == :type_rvalue_ref

        # Get the declaration of the type
        decl = type.declaration
        return true if decl.kind == :cursor_no_decl_found

        # For classes/structs, check if copy constructor is accessible
        # Also check base classes since a derived class inherits the copy constructor restriction
        if decl.kind == :cursor_struct || decl.kind == :cursor_class_decl
          return false unless copyable_class?(decl)
        end

        true
      end

      # Helper method to check if a class/struct has an accessible copy constructor.
      # Recursively checks base classes since copy restriction is inherited.
      def copyable_class?(decl)
        # Find all constructors in this class
        constructors = decl.find_by_kind(false, :cursor_constructor)
        copy_constructors = constructors.select(&:copy_constructor?)

        # If there are explicit copy constructors, check their accessibility
        copy_constructors.each do |ctor|
          # C++11: deleted copy constructor
          return false if ctor.deleted?
          # C++03: private copy constructor
          return false if ctor.private?
        end

        # Check base classes - if any base class is non-copyable, this class is too
        base_specifiers = decl.find_by_kind(false, :cursor_cxx_base_specifier)
        base_specifiers.each do |base|
          base_decl = base.type.declaration
          next if base_decl.kind == :cursor_no_decl_found
          return false unless copyable_class?(base_decl)
        end

        true
      end

      # Check if a class/struct has an accessible copy assignment operator.
      # Returns false if operator= is private, protected, or deleted.
      def copy_assignable_class?(decl)
        decl.find_by_kind(false, :cursor_cxx_method).each do |method|
          next unless method.spelling == "operator="
          return false if method.deleted? || method.private? || method.protected?
        end
        true
      end

      # Check if a type should use ArgBuffer (for parameters) or ReturnBuffer (for return types).
      # Returns true if the type is:
      #   - A pointer to a fundamental type (int*, double*, char*, etc.)
      #   - A double pointer (T**) - pointer to any pointer type
      # Types that look like pointers to fundamentals but are actually strings
      # char* and wchar_t* are C strings, not buffers
      STRING_POINTER_TYPES = [
        :type_char_u,   # char (unsigned on some platforms)
        :type_char_s,   # char (signed on some platforms)
        :type_wchar     # wchar_t (wide strings)
      ].freeze

      def buffer_type?(type)
        return false unless type.kind == :type_pointer

        pointee = type.pointee
        # Use canonical type to resolve template type parameters (e.g., _Tp* -> float*)
        pointee_kind = pointee.canonical.kind

        # Exclude string types - char* and wchar_t* are C strings, not buffers
        return false if STRING_POINTER_TYPES.include?(pointee_kind)

        # Case 1: Pointer to fundamental type (int*, double*, etc.)
        # This includes unsigned char* (uchar*) for byte buffers
        return true if FUNDAMENTAL_TYPES.include?(pointee_kind)

        # Case 2: Double pointer (T**) - pointer to any pointer
        return true if pointee_kind == :type_pointer

        false
      end

      # Get full template arguments including default values.
      # When a typedef uses a template with default arguments, the canonical spelling
      # may omit those defaults (e.g., Matx<uchar, 2> instead of Matx<uchar, 2, 1>).
      # This method compares the actual arguments with the template parameters and
      # appends any missing default values.
      def get_full_template_arguments(underlying_type, cursor_template)
        # Extract template arguments from canonical spelling, qualified
        qualified_spelling = qualify_template_args(underlying_type.canonical.spelling, underlying_type)
        match = qualified_spelling.match(/\<(.*)\>/)
        return "" unless match

        extracted_args = match[1]

        # Get template parameters from class template
        template_parameter_kinds = [:cursor_template_type_parameter,
                                    :cursor_non_type_template_parameter,
                                    :cursor_template_template_parameter]
        template_params = cursor_template.find_by_kind(false, *template_parameter_kinds)
        expected_count = template_params.length

        # Count extracted arguments (handle nested templates by counting only top-level commas)
        extracted_count = count_template_args(extracted_args)

        return extracted_args if extracted_count >= expected_count

        # Need to fill in defaults for missing parameters
        missing_params = template_params.last(expected_count - extracted_count)
        default_values = missing_params.map do |param|
          get_template_param_default(param)
        end.compact

        # If we couldn't get all defaults, return what we have
        return extracted_args if default_values.length != missing_params.length

        extracted_args + ", " + default_values.join(", ")
      end

      # Count template arguments at the top level (not inside nested <>)
      def count_template_args(args_string)
        return 0 if args_string.nil? || args_string.empty?

        count = 1
        depth = 0
        args_string.each_char do |c|
          case c
          when '<' then depth += 1
          when '>' then depth -= 1
          when ','
            count += 1 if depth == 0
          end
        end
        count
      end

      # Extract default value from a template parameter
      def get_template_param_default(param)
        if param.kind == :cursor_non_type_template_parameter
          # For non-type params (int, etc.), look for literal child
          default_child = nil
          param.each(false) do |child, _|
            default_child = child
          end
          return default_child.extent.text if default_child
        elsif param.kind == :cursor_template_type_parameter
          # For type params, parse extent text (e.g., "typename U = int")
          extent_text = param.extent.text rescue nil
          if extent_text && extent_text.include?('=')
            # Extract type after '=' and clean up
            default_type = extent_text.split('=', 2).last.strip
            return default_type unless default_type.empty?
          end
        end
        nil
      end

      # Qualify template arguments in a type spelling
      # e.g., DataType<hfloat> -> DataType<cv::hfloat>
      # Uses the canonical type to extract fully qualified names
      def qualify_template_args(spelling, type)
        return spelling if spelling.nil? || !spelling.include?('<')

        # Build a map of simple_name -> qualified_name from the canonical type
        # Start with @type_name_map, then override with canonical type qualifications
        # which are more specific to this context
        qualifications = @type_name_map.dup
        collect_type_qualifications(type.canonical, qualifications) if type

        # Apply qualifications to the spelling
        result = spelling.dup
        qualifications.each do |simple_name, qualified_name|
          next if simple_name == qualified_name
          # Replace unqualified occurrences (not preceded by :: or word char)
          result = result.gsub(/(?<![:\w])#{Regexp.escape(simple_name)}(?!\w)/, qualified_name)
        end

        result
      end

      # Recursively collect simple_name -> qualified_name mappings from a type's template arguments
      def collect_type_qualifications(type, qualifications)
        return if type.nil? || type.kind == :type_invalid
        return unless type.num_template_arguments > 0

        type.num_template_arguments.times do |i|
          arg_type = type.template_argument_type(i)
          next if arg_type.kind == :type_invalid

          # Handle pointer types - get the pointee
          check_type = arg_type
          check_type = check_type.pointee while check_type.kind == :type_pointer

          # Get declaration info
          decl = check_type.declaration
          if decl.kind != :cursor_no_decl_found
            simple_name = decl.spelling
            # For typedefs inside class templates (like cv::Mat_<_Tp>::iterator),
            # qualified_name returns cv::Mat_::iterator (missing template params).
            # Use qualified_display_name of the parent to preserve template params.
            qualified_name = if decl.kind == :cursor_typedef_decl && decl.semantic_parent.kind == :cursor_class_template
                               "#{decl.semantic_parent.qualified_display_name}::#{simple_name}"
                             else
                               decl.qualified_name
                             end
            if !simple_name.empty? && simple_name != qualified_name
              qualifications[simple_name] = qualified_name
            end
          end

          # Recurse into nested template arguments
          collect_type_qualifications(arg_type, qualifications)
        end
      end

      # Get qualified C++ class name for use in templates
      # Qualifies any template arguments that need namespace prefixes
      def qualified_class_name_cpp(cursor)
        qualify_template_args(cursor.class_name_cpp, cursor.type)
      end

      # Get qualified display name for a cursor
      # Qualifies any template arguments that need namespace prefixes
      # Used for generating fully qualified names in enum constants, etc.
      def qualified_display_name_cpp(cursor)
        qualify_template_args(cursor.qualified_display_name, cursor.type)
      end

      # Qualify dependent types within template arguments
      # e.g., "cv::Point_<typename DataType<_Tp>::channel_type>"
      #    -> "cv::Point_<typename cv::DataType<_Tp>::channel_type>"
      # Looks for patterns like "typename SomeClass<...>::member" and qualifies using @type_name_map
      def qualify_dependent_types_in_template_args(spelling)
        return spelling unless spelling.include?('typename')

        # Match "typename ClassName<...>::" patterns where ClassName might need qualification
        spelling.gsub(/typename\s+([A-Za-z_][A-Za-z0-9_]*)(<[^>]+>)?::/) do |match|
          class_name = $1
          template_part = $2 || ''
          qualified = @type_name_map[class_name]
          if qualified && qualified != class_name
            "typename #{qualified}#{template_part}::"
          else
            match
          end
        end
      end

      def type_spellings(cursor)
        cursor.type.arg_types.map do |arg_type|
          type_spelling(arg_type)
        end
      end

      # Patterns indicating internal STL implementation types that shouldn't be used directly.
      # - __gnu_cxx: libstdc++ extension namespace
      # - __normal_iterator: libstdc++ internal iterator wrapper
      # - \b_[A-Z]: MSVC internal types (e.g., _Ty, _Alloc)
      IMPL_CRUFT = /__gnu_cxx|__normal_iterator|\b_[A-Z]/

      # Returns a fully-qualified C++ type spelling suitable for use in generated Rice bindings.
      #
      # WHY THIS IS COMPLEX:
      # libclang's canonical type spelling fails for several C++ features:
      #
      # | Feature        | Why canonical fails                        | Correct libclang approach                    |
      # |----------------|--------------------------------------------|--------------------------------------------- |
      # | Typedefs       | Flattens to underlying primitive           | Handle cursor_typedef_decl explicitly        |
      # | Templates      | Loses specialized arguments/context        | Traverse cursor_template_ref and arguments   |
      # | Dependent types| Cannot resolve without instantiation       | Use type.spelling + typename logic           |
      # | Namespaces     | Often strips prefix to global root         | Recursive parent traversal via semantic_parent|
      #
      # libclang also provides:
      # - type.spelling: What programmer wrote (often unqualified)
      # - declaration.qualified_name: Has namespace but loses template args
      #
      # None of these work universally, so we handle each declaration kind separately,
      # combining information from spelling, qualified_name, and canonical as appropriate.
      def type_spelling(type)
        case type.kind
        when :type_lvalue_ref
          "#{type_spelling(type.non_reference_type)}&"
        when :type_rvalue_ref
          "#{type_spelling(type.non_reference_type)}&&"
        when :type_pointer
          ptr_const = type.const_qualified? ? " const" : ""
          "#{type_spelling(type.pointee)}*#{ptr_const}"
        when :type_incomplete_array
          type.canonical.spelling
        when :type_elaborated
          type_spelling_elaborated(type)
        else
          type.spelling
        end
      end

      # Handles :type_elaborated - the most complex case because libclang returns different
      # declaration kinds depending on what the type refers to, and each needs different handling.
      def type_spelling_elaborated(type)
        decl = type.declaration
        const_prefix = type.const_qualified? ? "const " : ""

        case decl.kind
        when :cursor_class_template
          # Class template definition (e.g., template<typename T> class Vec).
          # Use qualify_dependent_types_in_template_args (NOT qualify_template_args) because
          # template parameters like "_Tp" shouldn't be looked up in @type_name_map.
          spelling = type.spelling
          qualified = spelling.match(/\w+::/) ? spelling : spelling.sub(decl.spelling, decl.qualified_name)
          qualify_dependent_types_in_template_args(qualified)

        when :cursor_typedef_decl
          if decl.semantic_parent.kind == :cursor_class_template
            # Typedef inside a class template (e.g., DataType<_Tp>::value_type).
            # C++ requires 'typename' keyword for dependent types.
            parent = decl.semantic_parent
            display = parent.qualified_display_name
            qualified = parent.qualified_name
            full_parent = if display.include?('<') && !display.start_with?(qualified)
                            "#{qualified}#{display[display.index('<')..]}"
                          else
                            display
                          end
            "#{const_prefix}typename #{full_parent}::#{type.spelling.sub("const ", "")}"
          else
            # Regular typedef (e.g., typedef Point_<int> Point2i).
            # Must preserve typedef name - canonical would resolve to underlying type.
            type_spelling_typedef_or_alias(type, const_prefix)
          end

        when :cursor_type_alias_decl
          # C++11 using declaration (e.g., using iterator = __normal_iterator<...>).
          # MSVC uses 'using' where gcc uses 'typedef', so handle identically.
          type_spelling_typedef_or_alias(type, const_prefix)

        else
          # Class declarations, template instantiations, etc.
          # Here we CAN use canonical.spelling if it has better-qualified template args,
          # but only if it doesn't contain implementation cruft.
          base = type.fully_qualified_spelling

          canonical = type.canonical.spelling
          if base.include?('<') && canonical.include?('<') && !canonical.match?(IMPL_CRUFT)
            base_args = base[/<.*/] || ""
            canonical_args = canonical[/<.*/] || ""
            base = canonical if canonical_args.count(':') > base_args.count(':')
          end

          qualify_template_args(base, type)
        end
      end

      # Handles typedef and type_alias declarations (they use identical logic).
      # Preserves the typedef/alias name and qualifies any template arguments.
      def type_spelling_typedef_or_alias(type, const_prefix)
        spelling = type.spelling
        qualified = type.declaration.qualified_name

        if spelling.include?('<')
          "#{const_prefix}#{qualify_template_args(spelling, type)}"
        elsif qualified.end_with?(spelling.sub(/^const\s+/, ''))
          "#{const_prefix}#{qualified}"
        else
          spelling
        end
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
            class_name = qualified_display_name_cpp(parent)
            signature << class_name
            params = type_spellings(cursor)
            signature += params

          when :cursor_class_decl, :cursor_struct
            signature << qualified_display_name_cpp(cursor)
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
        params.each_with_index.map do |param, index|
          # Use parameter name if available, otherwise generate a default name (matches Rice convention)
          param_name = param.spelling.empty? ? "arg_#{index}" : param.spelling.underscore

          # Determine argument class: Arg, ArgBuffer, or constexpr for template type parameters
          type = param.type
          if type.kind == :type_pointer && type.pointee.kind == :type_unexposed
            # Template type parameter pointer (e.g., _Tp*) - use constexpr to decide at compile time
            # Note: check pointee.kind (not canonical.kind) to distinguish _Tp* from Mat_<_Tp>*
            type_param = type.pointee.spelling
            arg_class = "std::conditional_t<std::is_fundamental_v<#{type_param}>, ArgBuffer, Arg>"
          else
            # Concrete type - use ArgBuffer for fundamental pointers and double pointers
            arg_class = buffer_type?(type) ? "ArgBuffer" : "Arg"
          end
          result = "#{arg_class}(\"#{param_name}\")"

          # Check if there is a default value by looking for expression children.
          # The default value is an expression child (cursor_unexposed_expr) of the parameter.
          default_value = find_default_value(param)
          if default_value
            # Skip default value if the type is not copyable (Rice needs to copy default values internally).
            # This handles types with private (C++03) or deleted (C++11) copy constructors.
            if copyable_type?(param.type)
              # Use type_spelling to get fully qualified type name
              qualified_type = type_spelling(param.type)
              result << " = static_cast<#{qualified_type}>(#{default_value})"
            end
          end
          result
        end
      end

      # Finds the default value expression for a parameter and returns it with qualified type/function names.
      # For example, transforms "Range::all()" to "cv::Range::all()" and "noArray()" to "cv::noArray()".
      # Returns nil if no default value.
      # Finds the default value expression for a parameter and returns it with qualified names.
      #
      # Architecture: Separates text extraction from semantic analysis to avoid macro expansion issues.
      # - Text extraction: Uses param.extent.text (original source) to get the default value
      # - Semantic analysis: Uses cursor traversal only to identify what needs namespace qualification
      #
      # This approach is necessary because cursor extent text can reflect macro expansion on some platforms.
      # For example, on Windows UCRT, 'stdout' expands to '__acrt_iob_func', but we want to preserve 'stdout'.
      #
      # @param param [Cursor] A parameter cursor that may have a default value
      # @return [String, nil] The default value with qualified names, or nil if no default value
      def find_default_value(param)
        # Get the parameter's source text and verify it has a default value.
        # Template arguments like '4' in 'Vec<_Tp, 4>' also appear as literal children,
        # but they won't have '=' in the extent.
        param_extent = param.extent.text
        return nil unless param_extent&.include?('=')

        # Extract default value text from param_extent (everything after '=').
        # This gives us the original source text, unaffected by macro expansion.
        default_text = param_extent.sub(/.*?=\s*/, '')
        return nil if default_text.empty?

        # Find the default value expression cursor for semantic analysis.
        # We need this to traverse child cursors and find what needs qualification.
        # Note: cursor_paren_expr is included for Windows where macros like 'stdout' wrap in parens.
        default_value_kinds = [:cursor_unexposed_expr, :cursor_call_expr, :cursor_decl_ref_expr,
                               :cursor_cxx_typeid_expr, :cursor_paren_expr] + CURSOR_LITERALS
        default_expr = param.find_by_kind(false, *default_value_kinds).find do |expr|
          # Filter out decl_ref_expr that reference template parameters (part of type, not default value)
          if expr.kind == :cursor_decl_ref_expr
            ref = expr.referenced
            ref && ref.kind != :cursor_non_type_template_parameter && ref.kind != :cursor_template_type_parameter
          else
            true
          end
        end
        return nil unless default_expr

        # Phase 1: Qualify type references (e.g., Range::all() -> cv::Range::all())
        # Find type_ref and template_ref cursors to identify types that need namespace qualification.
        default_expr.find_by_kind(true, :cursor_type_ref, :cursor_template_ref).each do |type_ref|
          ref = type_ref.referenced
          next unless ref && ref.kind != :cursor_invalid_file

          begin
            # For typedefs in class templates, preserve template parameters in the qualified name
            qualified_name = if ref.kind == :cursor_typedef_decl && ref.semantic_parent.kind == :cursor_class_template
                               "#{ref.semantic_parent.qualified_display_name}::#{ref.spelling}"
                             else
                               ref.qualified_name
                             end
            simple_name = ref.spelling
            next if simple_name.nil? || simple_name.empty?
            next if simple_name == qualified_name

            # Replace unqualified occurrences (negative lookbehind avoids already-qualified names)
            default_text = default_text.gsub(/(?<!::)\b#{Regexp.escape(simple_name)}\b/, qualified_name)
          rescue ArgumentError
            # Skip if we can't get qualified name (e.g., invalid cursor)
          end
        end

        # Phase 2: Qualify declaration references (functions, enum values, static members)
        # For example: noArray() -> cv::noArray(), NORM_L2 -> cv::NORM_L2
        decl_refs = default_expr.find_by_kind(true, :cursor_decl_ref_expr)
        decl_refs = [default_expr] + decl_refs if default_expr.kind == :cursor_decl_ref_expr
        decl_refs.each do |decl_ref|
          ref = decl_ref.referenced
          next unless ref && ref.kind != :cursor_invalid_file

          begin
            # Use ref.spelling (the symbol's declared name) rather than extent.text.
            # This gives us what the symbol is actually named, not what text appears in source.
            simple_name = ref.spelling
            next if simple_name.nil? || simple_name.empty?

            # Skip methods already qualified in source (e.g., Range::all() has 'all' after '::')
            if ref.kind == :cursor_cxx_method
              next if default_text.match?(/::#{Regexp.escape(simple_name)}\s*\(/)
            end

            # Determine the correct qualified name based on declaration context
            qualified_name = if ref.kind == :cursor_enum_constant_decl &&
                                ref.semantic_parent.kind == :cursor_enum_decl &&
                                !ref.semantic_parent.enum_scoped?
                               # Unscoped (C-style) enum: values are in enclosing scope, not under enum type
                               # e.g., cv::DECOMP_SVD (correct), not cv::DecompTypes::DECOMP_SVD
                               enum_parent = ref.semantic_parent.semantic_parent
                               if enum_parent && enum_parent.kind == :cursor_namespace
                                 "#{enum_parent.qualified_name}::#{simple_name}"
                               elsif ref.semantic_parent.anonymous?
                                 # Anonymous enum in class: cv::Mat::AUTO_STEP, not cv::Mat::(unnamed)::AUTO_STEP
                                 "#{enum_parent.qualified_name}::#{simple_name}"
                               else
                                 ref.qualified_name
                               end
                             elsif ref.semantic_parent.kind == :cursor_class_template
                               # Class template members need qualified_display_name to preserve template params
                               "#{ref.semantic_parent.qualified_display_name}::#{simple_name}"
                             else
                               ref.qualified_name
                             end

            next if simple_name == qualified_name
            next if qualified_name.start_with?('::')

            # Skip macro identifiers: if qualified_name doesn't end with simple_name, the cursor
            # resolved through a macro to a different symbol (e.g., stdout -> __acrt_iob_func on Windows).
            # We want to keep the original source text in these cases.
            next unless qualified_name.end_with?(simple_name)

            # Apply qualification (negative lookbehind avoids double-qualifying)
            default_text = default_text.gsub(/(?<!::)\b#{Regexp.escape(simple_name)}\b/, qualified_name)
          rescue ArgumentError
            # Skip if we can't get qualified name
          end
        end

        # Phase 3: Qualify any remaining type names using @type_name_map.
        # This catches cases not found via cursor traversal, like template constructor calls
        # (e.g., Rect_<double>(...) where there's no template_ref cursor in the expression).
        @type_name_map.each do |simple_name, qualified_name|
          next if simple_name == qualified_name
          default_text = default_text.gsub(/(?<![:\w])#{Regexp.escape(simple_name)}(?![:\w])/, qualified_name)
        end

        default_text
      end

      # Qualify nested typedefs from a class template in a type spelling
      # e.g., "std::reverse_iterator<iterator>" -> "std::reverse_iterator<cv::Mat_<_Tp>::iterator>"
      def qualify_class_template_typedefs(spelling, class_template)
        return spelling unless class_template&.kind == :cursor_class_template

        # Collect typedef names from the class template
        typedef_names = []
        class_template.each do |child|
          if child.kind == :cursor_typedef_decl || child.kind == :cursor_type_alias_decl
            typedef_names << child.spelling
          end
        end

        return spelling if typedef_names.empty?

        # Get the qualified class template name with template params
        qualified_parent = class_template.qualified_display_name

        result = spelling.dup
        typedef_names.each do |name|
          # Replace unqualified typedef names (not preceded by :: or word char)
          result = result.gsub(/(?<![:\w])#{Regexp.escape(name)}(?![:\w])/, "#{qualified_parent}::#{name}")
        end

        result
      end

      def method_signature(cursor)
        param_types = type_spellings(cursor)
        result_type = type_spelling(cursor.type.result_type)

        # Qualify nested typedefs from class template in result type and param types
        if cursor.semantic_parent&.kind == :cursor_class_template
          result_type = qualify_class_template_typedefs(result_type, cursor.semantic_parent)
          param_types = param_types.map { |pt| qualify_class_template_typedefs(pt, cursor.semantic_parent) }
        end

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

      # Common skip checks for functions and methods
      def skip_callable?(cursor)
        skip_symbol?(cursor) ||
          cursor.availability == :deprecated ||
          cursor.spelling.end_with?('_')
      end

      def visit_cxx_method(cursor)
        # Do not process method definitions outside of classes (because we already processed them)
        return if cursor.lexical_parent != cursor.semantic_parent
        return if skip_callable?(cursor)

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

        # Check if return type should use ReturnBuffer
        return_buffer = buffer_type?(cursor.result_type)

        is_template = cursor.semantic_parent.kind == :cursor_class_template
        result << self.render_cursor(cursor, "cxx_method",
                                     :name => name,
                                     :is_template => is_template,
                                     :signature => signature,
                                     :args => args,
                                     :return_buffer => return_buffer)

        # Special handling for implementing #[](index, value)
        if cursor.spelling == "operator[]" && cursor.result_type.kind == :type_lvalue_ref &&
           !cursor.result_type.non_reference_type.const_qualified? && !cursor.const?
          result << self.render_cursor(cursor, "operator[]",
                                       :name => name)
        end
        result
      end

      # Check if an iterator type has proper std::iterator_traits.
      # Returns nil if traits are complete, or a hash with inferred traits if incomplete.
      def check_iterator_traits(iterator_type)
        # Get the declaration of the iterator type
        decl = iterator_type.declaration
        return nil if decl.kind == :cursor_no_decl_found

        # Skip std:: types - they already have iterator_traits
        qualified_name = decl.qualified_name
        return nil if qualified_name&.start_with?('std::')

        # If decl is a typedef, get the underlying type's declaration
        # e.g., typedef SparseMatConstIterator_<uchar> SparseMatConstIterator
        if decl.kind == :cursor_typedef_decl || decl.kind == :cursor_type_alias_decl
          underlying_type = iterator_type.canonical
          underlying_decl = underlying_type.declaration
          decl = underlying_decl if underlying_decl.kind != :cursor_no_decl_found
        end

        # Check for required typedefs: value_type, reference, pointer, difference_type, iterator_category
        has_value_type = false
        has_reference = false
        has_pointer = false
        has_difference_type = false
        has_iterator_category = false

        decl.each(false) do |child, _|
          if child.kind == :cursor_type_alias_decl || child.kind == :cursor_typedef_decl
            case child.spelling
            when "value_type" then has_value_type = true
            when "reference" then has_reference = true
            when "pointer" then has_pointer = true
            when "difference_type" then has_difference_type = true
            when "iterator_category" then has_iterator_category = true
            end
          end
        end

        # If all traits are present, return nil (no specialization needed)
        return nil if has_value_type && has_reference && has_pointer && has_difference_type && has_iterator_category

        # Infer traits from operator* return type
        # Use recursive iteration to find inherited methods from base classes
        # Note: Iterators without operator* (like OpenCV's SparseMatConstIterator which uses node())
        # cannot have traits auto-generated. Add them to skip_symbols in the config.
        value_type = nil
        decl.each do |child, _|
          if child.kind == :cursor_cxx_method && child.spelling == "operator*"
            result_type = child.result_type
            # Remove reference to get the value type
            if result_type.kind == :type_lvalue_ref
              value_type = result_type.non_reference_type.spelling
            else
              value_type = result_type.spelling
            end
            break
          end
        end

        return nil unless value_type  # Can't infer traits without operator*

        # Get fully qualified iterator type name from declaration
        # This works for non-std types since we skip std:: types above
        qualified_iterator = qualified_name

        # Qualify the value type if needed
        qualified_value_type = value_type.sub(/\s*const\s*$/, '')  # Remove trailing const
        # If value_type isn't already qualified, try to qualify it using type_name_map
        unless qualified_value_type.include?('::')
          if @type_name_map && @type_name_map[qualified_value_type]
            qualified_value_type = @type_name_map[qualified_value_type]
          end
        end

        # Return inferred traits
        {
          iterator_type: qualified_iterator,
          value_type: qualified_value_type,
          is_const: value_type.include?('const')
        }
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

        # Check if iterator needs std::iterator_traits specialization
        iterator_type = cursor.result_type
        traits = check_iterator_traits(iterator_type)
        if traits
          # Record this iterator for traits generation (use type as key to avoid duplicates)
          @incomplete_iterators[traits[:iterator_type]] = traits
        end

        self.render_cursor(cursor, "cxx_iterator_method", :name => iterator_name,
                           :begin_method => begin_method, :end_method => end_method,
                           :signature => signature,
                           :is_template => is_template)
      end

      def visit_conversion_function(cursor)
        # For now only deal with member functions
        return unless CURSOR_CLASSES.include?(cursor.lexical_parent.kind)

        # Skip deprecated conversion operators
        return if cursor.availability == :deprecated

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
        return if skip_callable?(cursor)
        return unless has_export_macro?(cursor)
        return if cursor.type.variadic?

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

        # Check if return type should use ReturnBuffer
        return_buffer = buffer_type?(cursor.type.result_type)

        under = cursor.ancestors_by_kind(:cursor_namespace).first
        self.render_cursor(cursor, "function",
                           :under => under,
                           :name => name,
                           :signature => signature,
                           :args => args,
                           :return_buffer => return_buffer)
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
        # Skip anonymous namespaces - they're internal implementation details
        return if cursor.anonymous?

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

        # Collect non-member operators to render grouped by class later
        @non_member_operators[class_cursor.cruby_name] << { cursor: cursor, class_cursor: class_cursor }
        nil
      end

      def render_non_member_operators
        # First, separate ostream operators (they go on the second arg's class)
        # from regular operators (they go on the first arg's class)
        grouped = Hash.new { |h, k| h[k] = [] }

        @non_member_operators.each do |cruby_name, operators|
          operators.each do |op|
            cursor = op[:cursor]

            # Handle ostream << specially - generates inspect method on the second arg's class
            if cursor.spelling.match(/<</) && cursor.type.arg_type(0).spelling.match(/ostream/)
              target_class = cursor.type.arg_type(1).non_reference_type.declaration.cruby_name
              arg_type = type_spelling(cursor.type.arg_type(1))
              grouped[target_class] << <<~CPP.strip
                define_method("inspect", [](#{arg_type} self) -> std::string
                  {
                    std::ostringstream stream;
                    stream << self;
                    return stream.str();
                  })
              CPP
            else
              arg0_type = type_spelling(cursor.type.arg_type(0))
              arg1_type = type_spelling(cursor.type.arg_type(1))
              result_type = type_spelling(cursor.result_type)
              op_symbol = cursor.spelling.sub(/^operator\s*/, '')
              ruby_name = cursor.ruby_name

              # Determine the appropriate return statement based on result type
              if result_type == "void"
                return_stmt = "self #{op_symbol} other;"
              elsif result_type.include?("&") && result_type.include?(arg0_type.gsub(/[&\s]/, ''))
                # Returns reference to self (e.g., FileStorage& operator<<)
                return_stmt = "self #{op_symbol} other;\n    return self;"
              else
                # Returns a value (e.g., bool, ptrdiff_t)
                return_stmt = "return self #{op_symbol} other;"
              end

              grouped[cruby_name] << <<~CPP.strip
                define_method("#{ruby_name}", [](#{arg0_type} self, #{arg1_type} other) -> #{result_type}
                  {
                    #{return_stmt}
                  })
              CPP
            end
          end
        end

        # Now render each group as a chained method call
        result = []
        grouped.each do |cruby_name, lines|
          next if lines.empty?
          result << "#{cruby_name}.\n    #{lines.join(".\n    ")};"
        end
        result.join("\n  \n  ")
      end

      def visit_typedef_decl(cursor)
        return if cursor.semantic_parent.kind == :cursor_class_decl || cursor.semantic_parent.kind == :cursor_struct

        # Skip if already processed (can happen when force-generating base classes)
        return if @classes.key?(cursor.cruby_name)

        # Skip typedefs to std:: types - Rice handles these automatically
        canonical = cursor.underlying_type.canonical.spelling
        return if canonical.start_with?("std::")

        cursor_template_ref = cursor.find_by_kind(false, :cursor_template_ref).first

        # Handle template case. For example:
        #   typedef Point_<int> Point2i;
        if cursor_template_ref
          # Skip if the template class is in skip_symbols
          return if skip_symbol?(cursor_template_ref.referenced)

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
        # Get template arguments including any default values that were omitted in the typedef
        template_arguments = get_full_template_arguments(underlying_type, cursor_template)

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
              unless @classes.key?(base_typedef.cruby_name)
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

        @classes[cursor.cruby_name] = template_specialization
        result + self.render_cursor(cursor, "class_template_specialization",
                           :cursor_template => cursor_template,
                           :template_specialization => template_specialization,
                           :template_arguments => template_arguments,
                           :base_ref => base_ref,
                           :base => base,
                           :base_spelling => base_spelling,
                           :under => under)
      end

      # Auto-instantiate a class template used as a parameter type without a typedef.
      def auto_instantiate_template(cursor_template, instantiated_type, under)
        return "" unless cursor_template
        match = instantiated_type.match(/\<(.*)\>/)
        return "" unless match

        cruby_name = "rb_c#{instantiated_type.gsub(/::|<|>|,|\s+/, ' ').split.map(&:capitalize).join}"
        return "" if @classes.key?(cruby_name)

        @classes[cruby_name] = instantiated_type
        render_template("class_template_specialization",
                        :cursor => cursor_template, :cursor_template => cursor_template,
                        :template_specialization => instantiated_type, :template_arguments => match[1],
                        :cruby_name => cruby_name, :base_ref => nil, :base => nil,
                        :base_spelling => nil, :under => under)
      end

      # Generate Ruby class name from a C++ template instantiation spelling
      # e.g., "Tests::Matx<unsigned char, 2, 1>" -> "MatxUnsignedChar21"
      def ruby_name_from_template(base_spelling, template_arguments)
        base_name = base_spelling.sub(/<.*>\z/, "").split("::").last.camelize
        args_name = split_template_args(template_arguments).map { |t|
          t.split("::").last.camelize
        }.join
        base_name + args_name
      end

      # Auto-generate a base class definition when no typedef exists for it.
      # When recursive: true, also generates any base classes of the base class.
      def auto_generate_base_class(base_ref, base_spelling, template_arguments, under, recursive: true)
        base_template_ref = base_ref.find_by_kind(false, :cursor_template_ref).first
        return "" unless base_template_ref

        base_template = base_template_ref.referenced
        base_template_arguments = base_spelling.match(/<(.+)>\z/)&.[](1) || template_arguments
        return "" unless base_template_arguments

        result = ""
        base_base_spelling = nil

        # Check if this base class has its own base that needs auto-generation
        if recursive
          base_base_ref = base_template.find_by_kind(false, :cursor_cxx_base_specifier).first
          if base_base_ref
            base_base_template_ref = base_base_ref.find_by_kind(false, :cursor_template_ref).first
            if base_base_template_ref
              namespace = base_spelling.split("<").first.split("::")[0..-2].join("::")
              base_base_name = base_base_template_ref.referenced.spelling

              # Build substitution map from template params to actual values
              template_params = base_template.find_by_kind(false, :cursor_template_type_parameter,
                                                           :cursor_non_type_template_parameter).map(&:spelling)
              template_arg_values = split_template_args(base_template_arguments)
              subs = template_params.each_with_index.to_h { |param, i| [param, template_arg_values[i]] }

              # Substitute template parameters with actual values
              base_base_type_spelling = base_base_ref.type.spelling
              if base_base_type_spelling =~ /<(.+)>\z/
                base_base_args = split_template_args($1).map { |arg| subs[arg] || arg }.join(', ')
                base_base_spelling = namespace.empty? ? "#{base_base_name}<#{base_base_args}>" : "#{namespace}::#{base_base_name}<#{base_base_args}>"

                if !@typedef_map[base_base_spelling] && !@auto_generated_bases.include?(base_base_spelling)
                  result = auto_generate_base_class(base_base_ref, base_base_spelling, base_base_args, under)
                end
              end
            end
          end
        end

        @auto_generated_bases << base_spelling
        ruby_name = ruby_name_from_template(base_spelling, base_template_arguments)
        cruby_name = "rb_c#{ruby_name}"

        @classes[cruby_name] = base_spelling
        result + render_template("auto_generated_base_class",
                        :cruby_name => cruby_name, :ruby_name => ruby_name,
                        :base_spelling => base_spelling, :base_base_spelling => base_base_spelling,
                        :base_template => base_template, :template_arguments => base_template_arguments,
                        :under => under)
      end

      # Auto-generate a template base class for a non-template derived class.
      # For example: class PlaneWarper : public WarperBase<PlaneProjector>
      def auto_generate_template_base_for_class(base_specifier, base_spelling, under)
        auto_generate_base_class(base_specifier, base_spelling, nil, under, recursive: false)
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
                           :qualified_name => qualified_display_name_cpp(cursor))
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
          # Don't add indentation to blank lines
          line.strip.empty? ? line : " " * indentation + line
        end.join
      end

      # Clean up whitespace issues in generated content:
      # - Collapse multiple consecutive blank lines to single blank line
      # - Remove blank lines before closing braces
      def cleanup_whitespace(content)
        # Collapse 2+ consecutive blank lines to single blank line
        content = content.gsub(/\n{3,}/, "\n\n")
        # Remove blank line before closing brace
        content = content.gsub(/\n\n(\s*\})/, "\n\\1")
        content
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

          # Check if class template is from the main file.
          # Note: from_main_file? doesn't work when -include is used, so manually check.
          unless class_template_cursor.file_location.file == class_template_cursor.translation_unit.file.name
            next :continue
          end

          # Skip if explicitly listed in skip_symbols
          if skip_symbol?(class_template_cursor)
            next :continue
          end

          @overloads_stack.push(cursor.overloads)
          results << visit_class_template_builder(class_template_cursor)
          @overloads_stack.pop
        end
        merge_children(results, :indentation => indentation, :separator => separator, :strip => strip)
      end

      def visit_children(cursor, exclude_kinds: Set.new, only_static: nil)
        results = Array.new
        cursor.each(false) do |child_cursor, parent_cursor|
          if child_cursor.location.in_system_header?
            next :continue
          end

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

      # Build a map from simple type names to qualified names.
      # This helps qualify unqualified type names in template arguments.
      # We include types from all files (not just main file) because template
      # arguments often reference types from included headers.
      def build_type_name_map(cursor)
        cursor.each(true) do |child, parent|
          case child.kind
          when :cursor_typedef_decl, :cursor_type_alias_decl
            # Map simple name to qualified name (e.g., "String" -> "cv::String")
            next if child.spelling.empty?
            @type_name_map[child.spelling] ||= child.qualified_name
          when :cursor_class_decl, :cursor_struct, :cursor_enum_decl, :cursor_class_template
            # Also include class/struct/enum declarations and class templates
            next if child.spelling.empty?
            @type_name_map[child.spelling] ||= child.qualified_name
          end
        end
      end

      # Given a typedef cursor and its underlying type, resolve the base class
      # to an actual instantiated type (e.g., PtrStep<unsigned char> instead of PtrStep<T>).
      # Correctly handles cases where derived and base templates have different numbers of
      # template parameters (e.g., Vec<_Tp, cn> : public Matx<_Tp, cn, 1>).
      # Returns the resolved base class spelling or nil if no base class exists.
      def resolve_base_instantiation(cursor, underlying_type)
        # Get template reference from the typedef
        template_ref = cursor.find_by_kind(false, :cursor_template_ref).first
        return nil unless template_ref

        derived_template = template_ref.referenced

        # Get base specifier from the template
        base_spec = derived_template.find_by_kind(false, :cursor_cxx_base_specifier).first
        return nil unless base_spec

        # Get the template reference in the base specifier
        base_template_ref = base_spec.find_by_kind(false, :cursor_template_ref).first

        # If there's no template ref, the base class is a non-template class (e.g., Mat_<_Tp> : public Mat)
        unless base_template_ref
          base_type_ref = base_spec.find_by_kind(false, :cursor_type_ref).first
          return base_type_ref&.referenced&.qualified_name
        end

        # Extract template arguments from the canonical spelling of the typedef
        canonical = underlying_type.canonical.spelling
        return nil unless canonical =~ /<(.+)>\z/

        template_args_str = $1

        # Get namespace from canonical (everything before the last ::Name<args>)
        namespace = canonical.split('<').first.split('::')[0..-2].join('::')

        # Get template parameter names from the derived template
        template_params = []
        derived_template.each do |c|
          if c.kind == :cursor_template_type_parameter || c.kind == :cursor_non_type_template_parameter
            template_params << c.spelling
          end
        end

        # Parse template argument values (handling nested templates with commas)
        template_arg_values = split_template_args(template_args_str)

        # Build substitution map: param_name -> actual_value
        subs = {}
        template_params.each_with_index do |param, i|
          subs[param] = template_arg_values[i] if template_arg_values[i]
        end

        # Get the base specifier's type spelling (e.g., "Matx<_Tp, cn, 1>")
        base_type_spelling = base_spec.type.spelling
        return nil unless base_type_spelling =~ /<(.+)>\z/

        base_args_str = $1

        # Split and substitute base template arguments
        base_args = split_template_args(base_args_str).map do |arg|
          subs[arg] || arg
        end

        # Construct the fully qualified base class instantiation
        base_name = base_template_ref.referenced.spelling
        resolved_args = base_args.join(', ')
        if namespace.empty?
          "#{base_name}<#{resolved_args}>"
        else
          "#{namespace}::#{base_name}<#{resolved_args}>"
        end
      end

      # Split template arguments string, respecting nested angle brackets
      # e.g., "int, std::pair<int, double>, 5" -> ["int", "std::pair<int, double>", "5"]
      def split_template_args(args_str)
        result = []
        current = String.new
        depth = 0

        args_str.each_char do |c|
          case c
          when '<'
            depth += 1
            current << c
          when '>'
            depth -= 1
            current << c
          when ','
            if depth == 0
              result << current.strip
              current = String.new
            else
              current << c
            end
          else
            current << c
          end
        end

        result << current.strip unless current.strip.empty?
        result
      end
    end
  end
end 