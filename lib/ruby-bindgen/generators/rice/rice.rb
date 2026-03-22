require 'set'

module RubyBindgen
  module Generators
    class Rice < Generator
      CURSOR_LITERALS = [:cursor_integer_literal, :cursor_floating_literal,
                         :cursor_imaginary_literal, :cursor_string_literal,
                         :cursor_character_literal, :cursor_cxx_bool_literal_expr,
                         :cursor_cxx_null_ptr_literal_expr, :cursor_fixed_point_literal,
                         :cursor_unary_operator]

      CURSOR_CLASSES = [:cursor_class_decl, :cursor_class_template, :cursor_struct]

      # Fundamental types that should use ArgBuffer/ReturnBuffer when passed/returned as pointers
      # Mapping of C++ operators to Ruby method names per Rice documentation
      # Keys use cursor spelling form (e.g., 'operator()') so they share the same
      # key namespace as user rename_methods.
      # Values can be:
      #   - String: direct mapping
      #   - Proc: called with cursor to determine mapping (for arity-dependent operators)
      OPERATOR_MAPPINGS = RubyBindgen::NameMapper.new([
        # Assignment operators - not overridable in Ruby
        ['operator=', 'assign'],
        ['operator+=', 'assign_plus'],
        ['operator-=', 'assign_minus'],
        ['operator*=', 'assign_multiply'],
        ['operator/=', 'assign_divide'],
        ['operator%=', 'assign_modulus'],

        # Bitwise assignment operators - not overridable in Ruby
        ['operator&=', 'assign_and'],
        ['operator|=', 'assign_or'],
        ['operator^=', 'assign_xor'],
        ['operator<<=', 'assign_left_shift'],
        ['operator>>=', 'assign_right_shift'],

        # Logical operators - && and || not overridable in Ruby
        ['operator&&', 'logical_and'],
        ['operator||', 'logical_or'],

        # Function call operator
        ['operator()', 'call'],

        # Member access through pointer (arrow operator)
        ['operator->', 'arrow'],

        # Increment/decrement - arity-dependent (prefix=0 args, postfix=1 arg)
        ['operator++', ->(cursor) { cursor.type.args_size == 0 ? 'increment' : 'increment_post' }],
        ['operator--', ->(cursor) { cursor.type.args_size == 0 ? 'decrement' : 'decrement_post' }],

        # Dereference vs multiply - arity-dependent (unary=0 args, binary=1 arg)
        ['operator*', ->(cursor) { cursor.type.args_size == 0 ? 'dereference' : '*' }],

        # Unary plus/minus vs binary - arity-dependent
        # Ruby uses +@ and -@ for unary operators, + and - for binary
        # Member: unary=0 args, binary=1 arg
        # Non-member: unary=1 arg, binary=2 args (but we check member arity here)
        ['operator+', ->(cursor) { cursor.type.args_size == 0 ? '+@' : '+' }],
        ['operator-', ->(cursor) { cursor.type.args_size == 0 ? '-@' : '-' }],

        # Pass-through operators - Ruby supports these directly
        ['operator/', '/'],
        ['operator%', '%'],
        ['operator&', '&'],
        ['operator|', '|'],
        ['operator^', '^'],
        ['operator~', '~'],
        ['operator<<', '<<'],
        ['operator>>', '>>'],
        ['operator==', '=='],
        ['operator!=', '!='],
        ['operator<', '<'],
        ['operator>', '>'],
        ['operator<=', '<='],
        ['operator>=', '>='],
        ['operator!', '!'],
        ['operator[]', '[]'],
      ]).freeze

      # Mapping of C++ type names to Ruby conversion method suffixes
      CONVERSION_TYPE_MAPPINGS = RubyBindgen::NameMapper.new([
        # Standard integer types
        ['int', 'i'],
        ['long', 'l'],
        ['long long', 'i64'],
        ['short', 'i16'],
        ['unsigned int', 'u'],
        ['unsigned long', 'ul'],
        ['unsigned long long', 'u64'],
        ['unsigned short', 'u16'],
        # Fixed-width integer types
        ['int8_t', 'i8'],
        ['int16_t', 'i16'],
        ['int32_t', 'i32'],
        ['int64_t', 'i64'],
        ['uint8_t', 'u8'],
        ['uint16_t', 'u16'],
        ['uint32_t', 'u32'],
        ['uint64_t', 'u64'],
        # Size type (platform-independent)
        ['size_t', 'size'],
        # Floating point types
        ['float', 'f32'],
        ['double', 'f'],
        ['long double', 'ld'],
        # Other types
        ['bool', 'bool'],
        ['std::string', 's'],
        ['std::__cxx11::basic_string<char>', 's'],
        ['std::basic_string<char>', 's'],
        ['basic_string<char>', 's'],
        ['char *', 's'],
        ['const char *', 's'],
      ]).freeze

      # std:: types that Rice converts to native Ruby types (no Rice wrapper exists).
      # string→String, string_view→String, complex→Complex, monostate→NilClass, tuple→Array.
      # Checked by declaration spelling (not qualified_name) to avoid inline namespace issues
      # (e.g., std::__cxx11::basic_string on libstdc++).
      RICE_NATIVE_TYPES = Set.new(%w[basic_string basic_string_view complex monostate tuple]).freeze

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

      def self.template_dir
        __dir__
      end

      def initialize(inputter, outputter, config)
        super(inputter, outputter, config)
        @include_header = config[:include]
        @init_names = Hash.new
        @namespaces = Set.new
        @classes = Hash.new  # Maps cruby_name -> C++ type for Data_Type<T> declarations
        @typedef_map = Hash.new
        @type_name_map = Hash.new  # Maps simple type names to qualified names
        @auto_generated_bases = Set.new
        @symbols = RubyBindgen::Symbols.new(config[:symbols] || {})
        @export_macros = config[:export_macros] || []
        @version_check = config[:version_check]
        raise ArgumentError, "version_check is required when symbols.versions is non-empty" if @symbols.has_versions? && !@version_check

        # Build naming tables: merge operator defaults with user config
        symbols_config = config[:symbols] || {}
        rename_types = RubyBindgen::NameMapper.from_config(symbols_config[:rename_types] || [])
        user_rename_methods = RubyBindgen::NameMapper.from_config(symbols_config[:rename_methods] || [])
        rename_methods = OPERATOR_MAPPINGS.merge(user_rename_methods)
        @namer = RubyBindgen::Namer.new(rename_types, rename_methods, CONVERSION_TYPE_MAPPINGS)
        # Non-member operators grouped by target class cruby_name
        @non_member_operators = Hash.new { |h, k| h[k] = [] }
        # Iterators that need std::iterator_traits specialization
        @incomplete_iterators = Hash.new
        # Iterator names per class (for aliasing each_const -> each)
        @class_iterator_names = Hash.new { |h, k| h[k] = Set.new }
      end

      def generate
        clang_args = @config[:clang_args] || []
        parser = RubyBindgen::Parser.new(@inputter, clang_args, libclang: @config[:libclang])
        ::FFI::Clang::Cursor.namer = @namer
        parser.generate(self)
      end

      # Check if a type references a skipped symbol by examining its declaration.
      # Unwraps pointers/references and checks template arguments recursively.
      def type_references_skipped_symbol?(type)
        # Unwrap pointers and references to get the underlying type
        if [:type_pointer, :type_lvalue_ref, :type_rvalue_ref].include?(type.kind) && type.respond_to?(:pointee)
          return type_references_skipped_symbol?(type.pointee)
        end

        # Check the type's own declaration (try both non-canonical and canonical
        # since dependent types like SkippedClass<T> may not resolve canonically)
        [type, type.canonical].each do |t|
          decl = t.declaration
          next if decl.kind == :cursor_no_decl_found
          return true if @symbols.skip?(decl)
        end

        # For dependent/unexposed types where no declaration is found (e.g., SkippedClass<T>
        # inside a class template), fall back to checking the type spelling
        if type.declaration.kind == :cursor_no_decl_found && type.canonical.declaration.kind == :cursor_no_decl_found
          return true if @symbols.skip_spelling?(type.spelling)
        end

        # Check template arguments recursively
        if type.num_template_arguments > 0
          type.num_template_arguments.times do |i|
            arg_type = type.template_argument_type(i)
            next if arg_type.kind == :type_invalid
            return true if type_references_skipped_symbol?(arg_type)
          end
        end

        false
      end

      # Check if any parameter type of a callable references a skipped symbol.
      def has_skipped_param_type?(cursor)
        (0...cursor.type.args_size).any? do |i|
          type_references_skipped_symbol?(cursor.type.arg_type(i))
        end
      end

      # Check if the return type of a callable references a skipped symbol.
      def has_skipped_return_type?(cursor)
        type_references_skipped_symbol?(cursor.type.result_type)
      end

      # Check if a cursor should be skipped based on symbols config.
      # Adds Rice-specific template-argument matching on top of basic lookup.
      def skip_symbol?(cursor)
        return true if @symbols.skip?(cursor)

        # Check if any template argument type references a skipped symbol
        type_references_skipped_symbol?(cursor.type)
      end

      def visit_start
        # Clear caches from previous runs
        @class_template_typedefs = {}
        @class_static_members = {}
      end

      def visit_end
        create_rice_include_header
        create_project_files
      end

      # Returns the path to the Rice include header (user-specified or auto-generated)
      def rice_include_header
        @include_header || "#{@project || 'rice'}_include.hpp"
      end

      # Compute the .ipp path for a template defined in a different file.
      def ipp_path_for_cursor(cursor)
        template_file = cursor.file_location.file
        relative = Pathname.new(template_file).relative_path_from(Pathname.new(@inputter.base_path)).to_s
        File.join(File.dirname(relative), "#{File.basename(relative, '.*')}-rb.ipp")
      end

      # Generate default Rice include header if user didn't specify one.
      # If the file already exists on disk, preserve it so user customizations are not lost.
      def create_rice_include_header
        return if @include_header  # User specified their own header

        header_path = rice_include_header
        output_path = self.outputter.output_path(header_path)
        if File.exist?(output_path)
          STDOUT << "  Preserving: " << header_path << "\n"
          return
        end

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
        @class_iterator_names.clear
        cursor = translation_unit.cursor
        @printing_policy = cursor.printing_policy

        # Build maps for typedef lookups and type name qualification
        build_typedef_map(cursor)

        # Figure out relative paths for generated header and cpp file
        @basename = "#{File.basename(relative_path, ".*")}-rb"
        @relative_dir = File.dirname(relative_path)
        rice_header = File.join(@relative_dir, "#{@basename}.hpp")
        rice_cpp = File.join(@relative_dir, "#{@basename}.cpp")

        # Track init names - use relative path to avoid conflicts (e.g., core/version vs dnn/version)
        path_parts = Pathname.new(relative_path).each_filename.to_a
        path_parts.shift if path_parts.length >= 2  # Remove top-level directory (e.g., opencv2)
        filename = Pathname.new(path_parts.pop).sub_ext('').to_s.camelize
        dir_part = path_parts.map(&:camelize).join('_')
        init_name = dir_part.empty? ? "Init_#{filename}" : "Init_#{dir_part}_#{filename}"
        @init_names[rice_header] = init_name

        @includes = Set.new
        @includes << "#include <#{relative_path}>"
        @includes << "#include \"#{@basename}.hpp\""

        class_templates, has_builders = render_class_templates(cursor)
        content = render_children(cursor, :indentation => 2)

        # Render non-member operators grouped by class
        non_member_ops = render_non_member_operators
        unless non_member_ops.empty?
          content = content + "\n\n  " + non_member_ops
        end

        # Generate .ipp file if builders exist (for reusability without duplicate Init symbols)
        rice_ipp = nil
        if has_builders
          rice_ipp = File.join(File.dirname(relative_path), "#{@basename}.ipp")
          STDOUT << "  Writing: " << rice_ipp << "\n"
          ipp_content = render_cursor(cursor, "translation_unit.ipp",
                                      :class_templates => class_templates)
          self.outputter.write(rice_ipp, ipp_content)
        end

        # Render C++ file
        STDOUT << "  Writing: " << rice_cpp << "\n"
        content = render_cursor(cursor, "translation_unit.cpp",
                                :class_templates => class_templates,
                                :content => content,
                                :includes => @includes,
                                :init_name => init_name,
                                :rice_header => rice_header,
                                :incomplete_iterators => @incomplete_iterators,
                                :rice_ipp => rice_ipp ? File.basename(rice_ipp) : nil)
        self.outputter.write(rice_cpp, content)

        # Render header file
        STDOUT << "  Writing: " << rice_header << "\n"
        # Compute relative path from translation unit directory to the include header
        relative_include = Pathname.new(rice_include_header).relative_path_from(File.dirname(relative_path)).to_s
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

        # Skip explicitly listed constructors
        return if skip_symbol?(cursor)

        # Do not process move constructors
        return if cursor.move_constructor?

        # Do not construct abstract classes
        return if cursor.semantic_parent.abstract?

        # Skip constructors that take skipped types as parameters
        return if has_skipped_param_type?(cursor)

        signature = constructor_signature(cursor)
        args = arguments(cursor)

        return unless signature

        self.render_cursor(cursor, "constructor",
                           :signature => signature, :args => args)
      end

      def visit_class_decl(cursor)
        # Skip explicitly listed symbols
        return if skip_symbol?(cursor)

        # Skip anonymous types with no definer (no typedef, field, or variable name).
        # These are unnameable in C++ and cannot be meaningfully bound.
        return if cursor.anonymous? && !cursor.anonymous_definer

        result = Hash.new { |h, k| h[k] = [] }

        # Determine containing module
        under = find_under(cursor)

        # Is there a base class?
        base = nil
        auto_generated_base = ""
        base_specifier = cursor.find_first_by_kind(false, :cursor_cxx_base_specifier)
        if base_specifier
          # Use canonical spelling for fully qualified type name with namespaces
          base = base_specifier.type.canonical.spelling

          # Check if base is a template instantiation that needs to be auto-generated
          if base.include?('<') && !@auto_generated_bases.include?(base)
            auto_generated_base = auto_generate_template_base_for_class(base_specifier, base, under)
          end
        end

        # Visit children
        versions = visit_children(cursor,
                                  exclude_kinds: Set[:cursor_class_decl, :cursor_struct, :cursor_enum_decl, :cursor_typedef_decl])

        # Are there any constructors? If not, C++ will define one implicitly
        # (but not for incomplete/opaque types which can't be instantiated)
        constructors = cursor.find_by_kind(false, :cursor_constructor)
        if !cursor.abstract? && !cursor.opaque_declaration? && constructors.none?
          versions[nil].unshift(self.render_template("constructor",
                                                     :cursor => cursor,
                                                     :signature => self.constructor_signature(cursor),
                                                     :args => []))
        end

        # Add anonymous enum constants to the class chain (with per-constant versioning)
        cursor.find_by_kind(false, :cursor_enum_decl) do |child_cursor|
          next if child_cursor.private? || child_cursor.protected?
          next unless child_cursor.anonymous?
          constant_versions = visit_children(child_cursor)
          constant_versions.each do |version, lines|
            versions[version].concat(lines.map(&:strip))
          end
        end

        children_content = merge_children(versions, indentation: 2, chain: true, terminate: true, strip: true)

        # Collect forward-declared (incomplete) inner classes
        # They must be registered with Rice before the parent class methods use them
        incomplete_classes = []
        cursor.find_by_kind(false, :cursor_class_decl, :cursor_struct) do |child_cursor|
          next if child_cursor.private? || child_cursor.protected?
          next unless child_cursor.opaque_declaration?
          incomplete_classes << visit_incomplete_class(child_cursor, cursor)
        end
        incomplete_classes_content = merge_children({ nil => incomplete_classes })

        # Auto-instantiate any class templates used as parameter types
        auto_instantiated = auto_instantiate_parameter_templates(cursor, under)
        result[nil] << auto_instantiated unless auto_instantiated.empty?

        # Render class
        @classes[cursor.cruby_name] = qualified_class_name_cpp(cursor)
        result[nil] << self.render_cursor(cursor, "class", :under => under, :base => base,
                                     :auto_generated_base => auto_generated_base,
                                     :incomplete_classes => incomplete_classes_content,
                                     :children => children_content)

        # Alias each_const to each if the class only has const iterators
        iterator_names = @class_iterator_names[cursor.cruby_name]
        if iterator_names.include?("each_const") && !iterator_names.include?("each")
          result[nil] << render_template("iterator_alias", :cruby_name => cursor.cruby_name)
        end

        # Define any complete embedded classes and structs
        cursor.find_by_kind(false, :cursor_class_decl, :cursor_struct) do |child_cursor|
          next if child_cursor.private? || child_cursor.protected?
          next if child_cursor.opaque_declaration?
          content = visit_class_decl(child_cursor)
          next unless content
          version = @symbols.version(child_cursor)
          result[version] << content
        end

        # Define any named embedded enums (anonymous enums are chained above)
        cursor.find_by_kind(false, :cursor_enum_decl) do |child_cursor|
          next if child_cursor.private? || child_cursor.protected?
          next if child_cursor.anonymous?
          version = @symbols.version(child_cursor)
          result[version] << visit_enum_decl(child_cursor)
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

          child.num_arguments.times do |i|
            param = child.argument(i)
            # Unwrap reference and pointer types
            type = param.type
            type = type.non_reference_type while type.kind == :type_lvalue_ref || type.kind == :type_rvalue_ref
            type = type.pointee while type.kind == :type_pointer

            # Skip if not a template instantiation or is from a system header (std::, etc.)
            next unless type.num_template_arguments > 0
            next if type.canonical.declaration.location.in_system_header?

            # Find class template declaration
            template_ref = param.find_first_by_kind(true, :cursor_template_ref)
            next unless template_ref
            decl = template_ref.referenced
            next unless decl.kind == :cursor_class_template
            next unless (decl.location.file == cursor.location.file rescue false)

            # Auto-instantiate if no typedef exists
            instantiated_type = type_spelling(type.unqualified_type)
            instantiated_type = qualify_class_static_members(instantiated_type, cursor)
            next if @typedef_map[instantiated_type]

            code = auto_instantiate_template(decl, instantiated_type, type, under)
            result << code unless code.empty?
          end
        end

        merge_children({ nil => result })
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

      # Get base class spelling from a cursor's base specifier.
      # Handles both template and non-template base classes.
      # Returns nil if no base class exists.
      def get_base_spelling(cursor)
        base_specifier = cursor.find_first_by_kind(false, :cursor_cxx_base_specifier)
        return nil unless base_specifier

        base_template_ref = base_specifier.find_first_by_kind(false, :cursor_template_ref)
        if base_template_ref
          ref = base_template_ref.referenced
          return nil unless ref

          # Skip system-header base classes (e.g., std::shared_ptr)
          return nil if ref.location.in_system_header?

          # Template base: use type spelling which has template params (e.g., Matx<_Tp, cn, 1>)
          base_spelling = base_specifier.type&.spelling
          return nil unless base_spelling

          # Qualify with namespace if needed
          ref_qualified = ref.qualified_name
          ref_spelling = ref.spelling
          return base_spelling unless ref_qualified && ref_spelling

          base_ns = ref_qualified.sub(ref_spelling, "")
          if !base_ns.empty? && !base_spelling.start_with?(base_ns)
            base_spelling = "#{base_ns}#{base_spelling}"
          end
          base_spelling
        else
          # Non-template base: use qualified name
          base_type_ref = base_specifier.find_first_by_kind(false, :cursor_type_ref)
          return nil unless base_type_ref

          ref = base_type_ref.referenced
          return nil if ref&.location&.in_system_header?

          ref.qualified_name
        end
      end

      def visit_class_template_builder(cursor)
        children_content = render_children(cursor,
                                          only_kinds: [:cursor_cxx_method, :cursor_constructor, :cursor_field_decl, :cursor_variable,
                                                       :cursor_enum_decl, :cursor_conversion_function],
                                          indentation: 4, chain: true,
                                          terminate: true, strip: true)

        base_spelling = get_base_spelling(cursor)

        template_parameter_kinds = [:cursor_template_type_parameter,
                                    :cursor_non_type_template_parameter,
                                    :cursor_template_template_parameter]

        # Filter out unnamed template parameters (e.g., `typename = void` default params)
        # — they have empty spelling and produce invalid C++ like `<T, >`
        template_parameters = cursor.find_by_kind(false, *template_parameter_kinds)
                                    .reject { |p| p.spelling.empty? }
        template_signature = template_parameters.map do |template_parameter|
          if template_parameter.kind == :cursor_template_type_parameter
            "typename #{template_parameter.spelling}"
          else
            type_spelling = template_parameter.type&.spelling || "int"
            "#{type_spelling} #{template_parameter.spelling}"
          end
        end.join(", ")

        # Build fully qualified type using template params (e.g., Tests::Matrix<T, Rows, Columns>)
        param_names = template_parameters.map(&:spelling).join(", ")
        fully_qualified_type = "#{cursor.qualified_name}<#{param_names}>"

        # Determine containing module
        under = find_under(cursor)

        # Render class
        result = Array.new
        result << self.render_cursor(cursor, "class_template", :under => under,
                                     :template_signature => template_signature,
                                     :fully_qualified_type => fully_qualified_type,
                                     :base_spelling => base_spelling,
                                     :children => children_content)

        merge_children({ nil => result })
      end

      # Find the nearest enclosing module (namespace, class, or struct), skipping
      # inline namespaces which don't map to Ruby modules.
      def find_under(cursor)
        cursor.ancestors_by_kind(:cursor_class_decl, :cursor_struct, :cursor_namespace)
              .find { |a| a.kind != :cursor_namespace || !a.inline_namespace? }
      end

      # Check if cursor has one of the required export macros in its source text
      # Used to filter out non-exported functions (e.g., only include CV_EXPORTS functions)
      def has_export_macro?(cursor)
        return true if @export_macros.empty?

        source_text = cursor.extent.text
        return false if source_text.nil?
        @export_macros.any? { |macro| source_text.include?(macro) }
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
        decl.find_by_kind(false, :cursor_cxx_method) do |method|
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
        template_params = cursor_template.find_by_kind(false, *template_parameter_kinds).to_a
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
          return qualify_template_non_type_default(param)
        elsif param.kind == :cursor_template_type_parameter
          return qualify_template_type_default(param)
        end
        nil
      end

      # Qualify source-written references within extracted default text by using
      # source ranges only for span location and semantic cursor data for the
      # replacement text.
      #
      # Examples:
      #   text = 'Box<Tag>'
      # becomes
      #   'QualifiedDefaults::Box<QualifiedDefaults::Tag>'
      #
      #   text = 'DefaultCount'
      # becomes
      #   'QualifiedDefaults::DefaultCount'
      #
      # The source is intentionally unqualified in the original namespace or
      # class scope. When the generated binding emits the same text outside that
      # scope, we need the fully qualified names from libclang, not the written
      # tokens from the source range.
      def qualify_source_default_references(root_cursor, source_text, source_text_offset, qualify_decl_refs: true)
        range_replacements = []
        type_fallbacks = []

        root_cursor.find_by_kind(true, :cursor_type_ref, :cursor_template_ref) do |type_ref|
          ref = type_ref.referenced
          next unless ref && ref.kind != :cursor_invalid_file

          # Template type parameters stay visible by bare name in generated
          # template code, so they should not be qualified here.
          next if ref.kind == :cursor_template_type_parameter

          begin
            is_dependent_typedef = ref.kind == :cursor_typedef_decl && ref.semantic_parent.kind == :cursor_class_template
            qualified_name = if is_dependent_typedef
                               "#{ref.semantic_parent.qualified_display_name}::#{ref.spelling}"
                             else
                               ref.qualified_name
                             end
            simple_name = ref.spelling
            next if simple_name.nil? || simple_name.empty?
            next if simple_name == qualified_name

            range = type_ref.reference_name_range([:want_qualifier, :want_template_args, :want_single_piece])
            replacement = source_range_replacement(source_text, source_text_offset, range)
            if replacement
              start_index = replacement[:start_offset] - source_text_offset
              end_index = replacement[:end_offset] - source_text_offset
              start_index = expand_name_start_to_qualifier(source_text, start_index)
              replacement = replacement.merge(start_offset: source_text_offset + start_index)
              span_text = source_text.byteslice(start_index, end_index - start_index)
              trailing_scope = source_text.byteslice(end_index, 2).to_s == '::'

              replacement_name = if ref.kind == :cursor_class_template && trailing_scope && !span_text.include?('<')
                                   ref.qualified_display_name
                                 else
                                   qualified_name
                                 end
              replacement_text = replacement_from_name_span(span_text, simple_name, replacement_name)
              if is_dependent_typedef && replacement_text && !trailing_scope &&
                 !preceded_by_typename?(source_text, start_index)
                replacement_text = "typename #{replacement_text}"
              end

              if replacement_text && replacement_text != span_text
                range_replacements << replacement.merge(replacement: replacement_text, kind: :type)
                next
              end
            end

            type_fallbacks << [ref, simple_name, qualified_name, is_dependent_typedef]
          rescue ArgumentError
            # Skip if we can't get qualified name (e.g., invalid cursor)
          end
        end

        decl_fallbacks = []
        if qualify_decl_refs
          decl_refs = root_cursor.find_by_kind(true, :cursor_decl_ref_expr).to_a
          decl_refs = [root_cursor] + decl_refs if root_cursor.kind == :cursor_decl_ref_expr
          decl_refs.each do |decl_ref|
            ref = decl_ref.referenced
            next unless ref && ref.kind != :cursor_invalid_file

            begin
              simple_name = ref.spelling
              next if simple_name.nil? || simple_name.empty?

              if ref.kind == :cursor_cxx_method
                next if source_text.match?(/::#{Regexp.escape(simple_name)}\s*\(/)
              end

              qualified_name = if ref.kind == :cursor_enum_constant_decl &&
                                  ref.semantic_parent.kind == :cursor_enum_decl &&
                                  !ref.semantic_parent.enum_scoped?
                                 enum_parent = ref.semantic_parent.semantic_parent
                                 if enum_parent && enum_parent.kind == :cursor_namespace
                                   "#{enum_parent.qualified_name}::#{simple_name}"
                                 elsif ref.semantic_parent.anonymous? &&
                                       enum_parent && enum_parent.kind != :cursor_translation_unit
                                   "#{enum_parent.qualified_name}::#{simple_name}"
                                 else
                                   ref.qualified_name
                                 end
                               elsif ref.semantic_parent.kind == :cursor_class_template
                                 "#{ref.semantic_parent.qualified_display_name}::#{simple_name}"
                               else
                                 ref.qualified_name
                               end

              next if simple_name == qualified_name
              next if qualified_name.start_with?('::')
              next unless qualified_name.end_with?(simple_name)

              range = if decl_ref.extent.text.include?('<')
                        decl_ref.spelling_name_range(0)
                      else
                        decl_ref.reference_name_range([:want_qualifier, :want_template_args, :want_single_piece])
                      end
              replacement = source_range_replacement(source_text, source_text_offset, range)
              if replacement
                start_index = replacement[:start_offset] - source_text_offset
                end_index = replacement[:end_offset] - source_text_offset
                span_text = source_text.byteslice(start_index, end_index - start_index)
                replacement_text = replacement_from_name_span(span_text, simple_name, qualified_name)
                if replacement_text && replacement_text != span_text
                  range_replacements << replacement.merge(replacement: replacement_text, kind: :decl)
                  next
                end
              end

              decl_fallbacks << [simple_name, qualified_name]
            rescue ArgumentError
              # Skip if we can't get qualified name
            end
          end

          decl_replacements = range_replacements.select { |replacement| replacement[:kind] == :decl }
          range_replacements.reject! do |replacement|
            replacement[:kind] == :type &&
              decl_replacements.any? do |decl_replacement|
                decl_replacement[:start_offset] <= replacement[:start_offset] &&
                  decl_replacement[:end_offset] >= replacement[:end_offset]
              end
          end
        end

        source_text = apply_source_replacements(source_text, source_text_offset, range_replacements) unless range_replacements.empty?

        type_fallbacks.each do |type_fallback|
          ref, simple_name, qualified_name, is_dependent_typedef = type_fallback
          source_text = fallback_qualify_type_reference(source_text, ref, simple_name, qualified_name, is_dependent_typedef)
        end

        decl_fallbacks.each do |decl_fallback|
          simple_name, qualified_name = decl_fallback
          source_text = fallback_qualify_declaration_reference(source_text, simple_name, qualified_name)
        end

        source_text
      end

      # Qualify a template type default using source spans for location and cursor
      # semantics for the replacement text.
      #
      # Examples:
      #   'typename U = Tag'
      # becomes
      #   'QualifiedDefaults::Tag'
      #
      #   'typename U = Box<Tag>'
      # becomes
      #   'QualifiedDefaults::Box<QualifiedDefaults::Tag>'
      #
      # The source range only tells us where `Tag` or `Box` was written. The
      # replacement text still comes from the referenced cursor because the
      # written text is intentionally unqualified inside the namespace.
      def qualify_template_type_default(param)
        extracted = extract_default_text(param)
        return nil unless extracted

        default_text, default_text_offset = extracted
        qualify_source_default_references(param, default_text, default_text_offset, qualify_decl_refs: false)
      end

      # Qualify a template non-type default using the same span-based rewrite as
      # function defaults.
      #
      # Examples:
      #   'int N = DefaultCount'
      # becomes
      #   'QualifiedDefaults::DefaultCount'
      #
      #   'int N = Holder<Tag>::value'
      # becomes
      #   'QualifiedDefaults::Holder<QualifiedDefaults::Tag>::value'
      def qualify_template_non_type_default(param)
        extracted = extract_default_text(param)
        return nil unless extracted

        default_text, default_text_offset = extracted
        qualify_source_default_references(param, default_text, default_text_offset)
      end

      # Qualify template arguments in a type spelling
      # e.g., DataType<hfloat> -> DataType<cv::hfloat>
      # Collects qualified names from both original and canonical types
      def qualify_template_args(spelling, type)
        return spelling if spelling.nil? || !spelling.include?('<')

        # Build a map of simple_name -> qualified_name from both the original type
        # (for typedefs like cv::String) and the canonical type (for concrete types)
        qualifications = {}
        if type
          collect_type_qualifications(type, qualifications)
          collect_type_qualifications(type.canonical, qualifications)
        end

        # Also look up unqualified names in @type_name_map (typedefs and class templates).
        # This handles cases like std::map<String, Value> where libclang's template_argument_type
        # returns the canonical type (std::string) instead of the typedef name (String).
        # Extract potential unqualified type names (not preceded by ::) and look them up.
        spelling.scan(/(?<![:\w])([A-Z_a-z]\w*)(?!\w)/) do |match|
          simple_name = match[0]
          next if qualifications.key?(simple_name)  # Already have qualification from type
          qualified_name = @type_name_map[simple_name]
          qualifications[simple_name] = qualified_name if qualified_name && simple_name != qualified_name
        end

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

      # Get the fully qualified class/struct type used in generated bindings.
      #
      # Examples:
      #   outer::Locale::Facet<Locale>
      # becomes
      #   outer::Locale::Facet<outer::Locale>
      #
      # This goes through type_spelling(cursor.type) instead of cursor-specific
      # string surgery. A class cursor's first child can be an unrelated type_ref,
      # which makes first-match substitution double-qualify nested specializations
      # like outer::outer::Locale::Facet<outer::Locale>.
      def qualified_class_name_cpp(cursor)
        type_spelling(cursor.type)
      end

      # Get qualified display name for a cursor
      # Qualifies any template arguments that need namespace prefixes
      # Used for generating fully qualified names in enum constants, etc.
      def qualified_display_name_cpp(cursor)
        # For members of template specializations, use the parent's type for qualification
        # e.g., TypeTraits<lowercase_type>::type needs lowercase_type qualified,
        # but cursor.type is just 'const int' which has no template args
        type = cursor.type
        parent = cursor.semantic_parent
        if parent && parent.type.num_template_arguments > 0
          type = parent.type
        end
        qualify_template_args(cursor.qualified_display_name, type)
      end

      # Qualify dependent types within template arguments
      # e.g., "cv::Point_<typename DataType<_Tp>::channel_type>"
      #    -> "cv::Point_<typename cv::DataType<_Tp>::channel_type>"
      # Also handles nested template args such as:
      #   "typename Outer_<Outer_<T>>::type"
      # -> "typename Tests::Outer_<Tests::Outer_<T>>::type"
      #
      # The source range APIs are not available here because libclang only gives us
      # a type spelling string at this point, so we do a small balanced parse of the
      # dependent base name and then qualify the nested template args recursively.
      def balanced_template_suffix(text, start_index)
        return ["", start_index] unless text[start_index] == '<'

        depth = 0
        index = start_index
        while index < text.length
          case text[index]
          when '<'
            depth += 1
          when '>'
            depth -= 1
            return [text[start_index..index], index + 1] if depth == 0
          end
          index += 1
        end

        ["", start_index]
      end

      def qualify_dependent_types_in_template_args(spelling)
        return spelling unless spelling.include?('typename')

        result = String.new
        index = 0

        while (match = /\btypename\b/.match(spelling, index))
          result << spelling[index...match.end(0)]
          index = match.end(0)

          while index < spelling.length && spelling[index].match?(/\s/)
            result << spelling[index]
            index += 1
          end

          identifier_match = /\A([A-Za-z_][A-Za-z0-9_]*)/.match(spelling[index..])
          unless identifier_match
            result << spelling[index]
            index += 1
            next
          end

          class_name = identifier_match[1]
          name_end = index + class_name.length
          template_part, after_template = balanced_template_suffix(spelling, name_end)
          unless spelling[after_template, 2] == '::'
            result << spelling[index...after_template]
            index = after_template
            next
          end

          qualified_name = @type_name_map[class_name] || class_name
          qualified_template_part = if template_part.empty?
                                      ""
                                    else
                                      qualify_template_args(qualify_dependent_types_in_template_args(template_part), nil)
                                    end

          result << "#{qualified_name}#{qualified_template_part}::"
          index = after_template + 2
        end

        result << spelling[index..] if index < spelling.length
        result
      end

      def type_spellings(cursor)
        cursor.type.arg_types.map do |arg_type|
          type_spelling(arg_type)
        end
      end

      # Returns a fully-qualified C++ type spelling suitable for use in generated Rice bindings.
      # Most type kinds are handled by Type#fully_qualified_name. This method only
      # intercepts elaborated types that need generator-level context:
      # - Class template types: fqn resolves template params, but template builders need them generic
      # - Typedefs inside class templates: need 'typename' keyword for dependent types
      # - Template instantiations: need qualify_template_args post-processing with @type_name_map
      def type_spelling(type)
        case type.kind
        when :type_lvalue_ref
          "#{type_spelling(type.non_reference_type)} &"
        when :type_rvalue_ref
          "#{type_spelling(type.non_reference_type)} &&"
        when :type_constant_array
          "#{type_spelling(type.element_type)}[#{type.size}]"
        when :type_incomplete_array
          "#{type_spelling(type.element_type)}[]"
        when :type_elaborated
          type_spelling_elaborated(type)
        else
          type.fully_qualified_name(@printing_policy)
        end
      end

      def type_spelling_elaborated(type)
        decl = type.declaration

        case decl.kind
        when :cursor_class_template
          # fqn resolves template params to concrete types (e.g., _Tp -> float),
          # but template builder code needs the generic parameter names preserved.
          spelling = type.spelling
          outer_name = spelling.sub(/\s*<.*/, '')
          qualified = outer_name.match?(/\w+::/) ? spelling : spelling.sub(decl.spelling, decl.qualified_name)
          qualify_dependent_types_in_template_args(qualified)

        when :cursor_typedef_decl, :cursor_type_alias_decl
          if decl.semantic_parent.kind == :cursor_class_template
            # Typedef/alias inside a class template (e.g., DataType<_Tp>::value_type).
            # C++ requires 'typename' keyword for dependent types.
            const_prefix = type.const_qualified? ? "const " : ""
            parent = decl.semantic_parent
            display = parent.qualified_display_name
            qualified = parent.qualified_name
            full_parent = if display.include?('<') && !display.start_with?(qualified)
                            "#{qualified}#{display[display.index('<')..]}"
                          else
                            display
                          end
            "#{const_prefix}typename #{full_parent}::#{type.unqualified_type.spelling}"
          else
            type.fully_qualified_name(@printing_policy)
          end

        else
          qualify_template_args(type.fully_qualified_name(@printing_policy), type)
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
            if cursor.semantic_parent&.kind == :cursor_class_template
              params = params.map { |pt| qualify_class_template_typedefs(pt, cursor.semantic_parent) }
            end
            if parent
              params = params.map { |pt| qualify_class_static_members(pt, parent) }
            end
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
        (0...cursor.num_arguments).map do |index|
          param = cursor.argument(index)
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
              if param.semantic_parent&.semantic_parent&.kind == :cursor_class_template
                qualified_type = qualify_class_template_typedefs(qualified_type, param.semantic_parent.semantic_parent)
              end
              # Can't static_cast to array types (e.g., using StepArray = int[3])
              decl = param.type.declaration
              is_array_alias = (decl.kind == :cursor_type_alias_decl || decl.kind == :cursor_typedef_decl) &&
                               [:type_constant_array, :type_incomplete_array].include?(decl.underlying_type.canonical.kind)
              if is_array_alias
                result << " = #{default_value}"
              elsif default_value == '{}'
                # Braced-init-list {} can't be used with static_cast (especially to
                # reference types). Use the canonical type for direct construction.
                base_type = qualified_type.sub(/\bconst\s+/, '').sub(/\s*&\s*$/, '')
                result << " = static_cast<#{qualified_type}>(#{base_type}{})"
              else
                result << " = static_cast<#{qualified_type}>(#{default_value})"
              end
            end
          end
          result
        end
      end

      # Convert a libclang source range into offsets relative to the extracted
      # default-expression text so semantic replacements can be applied safely.
      #
      # Example:
      #   text        = 'makePtr<inner::IndexParams>()'
      #   base_offset = 1200
      #   range       = source range for 'makePtr<inner::IndexParams>'
      #
      # Returns offsets relative to the file:
      #   { start_offset: 1200, end_offset: 1228, replacement: ... }
      #
      # Those offsets are later converted back into indexes relative to `text`
      # before patching only that exact span.
      def source_range_replacement(text, base_offset, range, replacement = nil)
        return nil if range.nil? || range.null?

        start_offset = range.start.offset
        end_offset = range.end.offset
        text_end_offset = base_offset + text.bytesize
        return nil if start_offset < base_offset || end_offset > text_end_offset || end_offset < start_offset

        { start_offset: start_offset, end_offset: end_offset, replacement: replacement }
      rescue ArgumentError
        nil
      end

      # Apply non-overlapping source replacements from right to left so earlier
      # offsets remain valid while rewriting a default expression.
      #
      # Example:
      #   text = 'helper("helper")'
      #   replacements = [{start_offset: ..., end_offset: ..., replacement: 'quoted::helper'}]
      #
      # Produces:
      #   'quoted::helper("helper")'
      #
      # The string literal stays untouched because only the decl-ref span is replaced.
      def apply_source_replacements(text, base_offset, replacements)
        replacements
          .uniq { |r| [r[:start_offset], r[:end_offset], r[:replacement]] }
          .sort_by { |r| -r[:start_offset] }
          .reduce(text.dup) do |result, replacement|
            start_index = replacement[:start_offset] - base_offset
            end_index = replacement[:end_offset] - base_offset
            result.byteslice(0, start_index) +
              replacement[:replacement] +
              result.byteslice(end_index..-1).to_s
          end
      end

      # Expand the written name span to the desired fully qualified form
      # without dropping template args or clobbering existing qualifiers.
      #
      # Examples:
      #   span_text       = 'helper'
      #   simple_name     = 'helper'
      #   qualified_name  = 'quoted::helper'
      #   => 'quoted::helper'
      #
      #   span_text       = 'makePtr<inner::IndexParams>'
      #   simple_name     = 'makePtr'
      #   qualified_name  = 'outer::makePtr'
      #   => 'outer::makePtr<inner::IndexParams>'
      #
      #   span_text       = 'PerfLevel::SLOW'
      #   simple_name     = 'SLOW'
      #   qualified_name  = 'multiline::PerfLevel::SLOW'
      #   => 'multiline::PerfLevel::SLOW'
      def replacement_from_name_span(span_text, simple_name, qualified_name)
        return qualified_name if span_text == simple_name
        return qualified_name if span_text.include?('::') && span_text.end_with?(simple_name)
        return span_text.sub(/\A#{Regexp.escape(simple_name)}/, qualified_name) if span_text.start_with?(simple_name)

        nil
      end

      # Check whether the source text immediately before a replacement span already
      # ends with `typename`, so we do not emit `typename typename Foo::Bar`.
      #
      # Examples:
      #   text        = 'typename SearchIndex<Distance>::ElementType()'
      #   start_index = index of the S in SearchIndex
      #   => true
      #
      #   text        = 'SearchIndex<Distance>::ElementType()'
      #   start_index = index of the S in SearchIndex
      #   => false
      def preceded_by_typename?(text, start_index)
        text.byteslice(0, start_index).to_s.match?(/(?:\A|[^\w:])typename\s+\z/)
      end

      # Extend a name-token span backward to include a written qualifier chain.
      #
      # Examples:
      #   text        = 'makePtr<inner::IndexParams>()'
      #   start_index = index of the I in IndexParams
      #   => index of the i in inner
      #
      #   text        = 'SearchIndex<Distance>::ElementType()'
      #   start_index = index of the E in ElementType
      #   => index of the S in SearchIndex
      def expand_name_start_to_qualifier(text, start_index)
        index = start_index

        loop do
          break unless index >= 2 && text.byteslice(index - 2, 2) == '::'

          segment_end = index - 2
          cursor = segment_end - 1
          break if cursor.negative?

          if text[cursor] == '>'
            depth = 0
            while cursor >= 0
              case text[cursor]
              when '>'
                depth += 1
              when '<'
                depth -= 1
                break if depth.zero?
              end
              cursor -= 1
            end
            break if cursor.negative?
            cursor -= 1
          end

          while cursor >= 0 && text[cursor].match?(/[A-Za-z0-9_]/)
            cursor -= 1
          end

          segment_start = cursor + 1
          break if segment_start == segment_end

          index = segment_start
        end

        index
      end

      def fallback_qualify_type_reference(text, ref, simple_name, qualified_name, is_dependent_typedef)
        # Replace unqualified occurrences (negative lookbehind avoids already-qualified names)
        result = text.gsub(/(?<!::)\b#{Regexp.escape(simple_name)}\b/, qualified_name)

        # Replace partially-qualified names (e.g., flann::Foo -> cv::flann::Foo)
        # Match any prefix::simple_name that isn't already fully qualified
        result = result.gsub(/(?<!\w)(\w+(?:::\w+)*)::#{Regexp.escape(simple_name)}\b/) do |match|
          match == qualified_name ? match : qualified_name
        end

        # For class template refs used as qualifiers (before ::) without explicit template args,
        # insert template parameters (e.g., CompositeIndex:: -> CompositeIndex<Distance>::)
        if ref.kind == :cursor_class_template
          display_name = ref.qualified_display_name
          result = result.gsub(/#{Regexp.escape(qualified_name)}(?=\s*::)/, display_name)
        end

        # Add 'typename' for dependent typedef names used as types (not as qualifiers before ::)
        # e.g., SearchIndex<Distance>::ElementType() needs typename, but Vec3Type::all() does not
        if is_dependent_typedef
          result = result.gsub(/(?<!typename )#{Regexp.escape(qualified_name)}(?!\s*::)/, "typename #{qualified_name}")
        end

        result
      end

      def fallback_qualify_declaration_reference(text, simple_name, qualified_name)
        # Apply qualification (negative lookbehind avoids double-qualifying)
        result = text.gsub(/(?<!::)\b#{Regexp.escape(simple_name)}\b/, qualified_name)

        # Replace partially-qualified names (e.g., fisheye::CALIB_FIX_INTRINSIC -> cv::fisheye::CALIB_FIX_INTRINSIC)
        # Match any prefix::simple_name that isn't already fully qualified
        result.gsub(/(?<!\w)(\w+(?:::\w+)*)::#{Regexp.escape(simple_name)}\b/) do |match|
          match == qualified_name ? match : qualified_name
        end
      end

      # Split a declaration at its default-value '=' and return both the written
      # default text and its byte offset in the source file.
      #
      # Examples:
      #   'FILE* stream = stdout'
      #   => ['stdout', <offset of the s in stdout>]
      #
      #   "PerfLevel level\n      = PerfLevel::SLOW"
      #   => ['PerfLevel::SLOW', <offset of the P in PerfLevel::SLOW>]
      #
      #   'typename U = Box<Tag>'
      #   => ['Box<Tag>', <offset of the B in Box<Tag>>]
      #
      # This is text extraction only. Qualification happens later using cursor
      # information so we do not lose semantic information for either function
      # defaults or template parameter defaults.
      def extract_default_text(param)
        param_extent = param.extent.text
        return nil unless param_extent

        before, separator, after = param_extent.partition('=')
        return nil if separator.empty?

        leading_whitespace = after[/\A\s*/] || ""
        default_text = after.delete_prefix(leading_whitespace)
        return nil if default_text.empty?

        default_text_offset = param.extent.start.offset + before.bytesize + separator.bytesize + leading_whitespace.bytesize
        [default_text, default_text_offset]
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
        # Extract default value text from param_extent (everything after '=').
        # This gives us the original source text, unaffected by macro expansion.
        # The '=' may be on a different line than the parameter type
        # (e.g., "PERF_LEVEL perfPreset\n        = NV_OF_PERF_LEVEL_SLOW").
        extracted = extract_default_text(param)
        return nil unless extracted
        default_text, default_text_offset = extracted

        # Find the default value expression cursor for semantic analysis.
        # We need this to traverse child cursors and find what needs qualification.
        # Note: cursor_paren_expr is included for Windows where macros like 'stdout' wrap in parens.
        default_value_kinds = [:cursor_unexposed_expr, :cursor_call_expr, :cursor_decl_ref_expr,
                               :cursor_c_style_cast_expr, :cursor_cxx_static_cast_expr,
                               :cursor_cxx_functional_cast_expr, :cursor_cxx_typeid_expr,
                               :cursor_paren_expr] + CURSOR_LITERALS
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

        qualify_source_default_references(default_expr, default_text, default_text_offset)
      end

      # Qualify nested typedefs from a class template in a type spelling
      # e.g., "std::reverse_iterator<iterator>" -> "std::reverse_iterator<cv::Mat_<_Tp>::iterator>"
      def qualify_class_template_typedefs(spelling, class_template)
        return spelling unless class_template&.kind == :cursor_class_template

        # Cache typedef names per class template to avoid repeated traversals
        @class_template_typedefs ||= {}
        cache_key = class_template.usr
        typedef_info = @class_template_typedefs[cache_key] ||= begin
          names = []
          class_template.each(false) do |child|
            child_kind = child.kind
            if child_kind == :cursor_typedef_decl || child_kind == :cursor_type_alias_decl
              names << child.spelling
            end
          end
          { names: names, qualified_parent: class_template.qualified_display_name }
        end

        return spelling if typedef_info[:names].empty?

        result = spelling.dup
        qualified_parent = typedef_info[:qualified_parent]
        typedef_info[:names].each do |name|
          unqualified = /(?<![:\w])#{Regexp.escape(name)}(?![:\w])/
          result = result.gsub(unqualified, "typename #{qualified_parent}::#{name}")
        end

        result
      end

      # Qualify bare class members used as non-type template args.
      # Within a class like GPCPatchDescriptor, a member can write
      # Vec<double, nFeatures> but the generated binding code is outside the
      # class, so it needs Vec<double, GPCPatchDescriptor::nFeatures>.
      # qualify_template_args then handles qualifying GPCPatchDescriptor to
      # cv::optflow::GPCPatchDescriptor.
      #
      # Unscoped enum constants need the same treatment:
      #   FixedBuffer<int, Size>
      # becomes
      #   FixedBuffer<int, Tests::EnumSized<N>::Size>
      #
      # Class templates need their template parameters preserved:
      #   FixedBuffer<int, Size>
      # becomes
      #   FixedBuffer<int, Tests::StaticSized<N>::Size>
      def qualify_class_static_members(spelling, class_cursor)
        return spelling unless class_cursor

        parent_kind = class_cursor.kind
        return spelling unless parent_kind == :cursor_class_decl ||
                              parent_kind == :cursor_struct ||
                              parent_kind == :cursor_class_template

        cache_key = class_cursor.usr
        member_info = @class_static_members[cache_key] ||= begin
          names = []
          class_cursor.each(false) do |child|
            if child.kind == :cursor_variable
              names << child.spelling
            elsif child.kind == :cursor_enum_decl && !child.enum_scoped?
              child.each(false) do |enum_child|
                names << enum_child.spelling if enum_child.kind == :cursor_enum_constant_decl
              end
            end
          end
          qualified_parent = if parent_kind == :cursor_class_template
                               qualified_display_name_cpp(class_cursor)
                             else
                               class_cursor.qualified_name
                             end
          { names: names, qualified_parent: qualified_parent }
        end

        return spelling if member_info[:names].empty?

        result = spelling.dup
        qualified_parent = member_info[:qualified_parent]
        member_info[:names].each do |name|
          unqualified = /(?<![:\w])#{Regexp.escape(name)}(?![:\w])/
          result = result.gsub(unqualified, "#{qualified_parent}::#{name}")
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

        # Qualify bare static const/constexpr members used as non-type template args
        # (e.g., nFeatures -> GPCPatchDescriptor::nFeatures)
        parent = cursor.semantic_parent
        if parent
          result_type = qualify_class_static_members(result_type, parent)
          param_types = param_types.map { |pt| qualify_class_static_members(pt, parent) }
        end

        signature = Array.new
        if cursor.kind == :cursor_function || cursor.static?
          signature << "#{result_type}(*)(#{param_types.join(', ')})"
        else
          signature << "#{result_type}(#{qualified_display_name_cpp(cursor.semantic_parent)}::*)(#{param_types.join(', ')})"
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
          cursor.type.variadic?
      end

      def visit_cxx_method(cursor)
        # Do not process method definitions outside of classes (because we already processed them)
        return if cursor.lexical_parent != cursor.semantic_parent
        return if skip_callable?(cursor)
        return if has_skipped_param_type?(cursor)
        return if has_skipped_return_type?(cursor)

        # Is this an iterator?
        if ITERATOR_METHODS.include?(cursor.spelling)
          return visit_cxx_iterator_method(cursor)
        end

        signature = method_signature(cursor)

        result = Array.new

        name = cursor.ruby_name
        args = arguments(cursor)

        # Check if return type should use ReturnBuffer
        return_buffer = buffer_type?(cursor.result_type)

        is_template = cursor.semantic_parent.kind == :cursor_class_template
        qualified_parent = qualified_display_name_cpp(cursor.semantic_parent)
        result << self.render_cursor(cursor, "cxx_method",
                                     :name => name,
                                     :is_template => is_template,
                                     :signature => signature,
                                     :args => args,
                                     :return_buffer => return_buffer,
                                     :qualified_parent => qualified_parent)

        # Special handling for implementing #[](index, value)
        if cursor.spelling == "operator[]" && cursor.result_type.kind == :type_lvalue_ref &&
           !cursor.result_type.non_reference_type.const_qualified? && !cursor.const?
          index_param = cursor.find_by_kind(false, :cursor_parm_decl).first
          index_type = type_spelling(cursor.type.arg_type(0))
          index_name = index_param&.spelling.to_s.empty? ? "index" : index_param.spelling
          result << self.render_cursor(cursor, "operator[]",
                                       :name => name,
                                       :index_type => index_type,
                                       :index_name => index_name,
                                       :qualified_parent => qualified_parent)
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
        # cannot have traits auto-generated. Add them to the skip list in the symbols config.
        value_type = nil
        value_type_decl = nil
        decl.each do |child, _|
          if child.kind == :cursor_cxx_method && child.spelling == "operator*"
            result_type = child.result_type
            # Remove reference to get the value type
            if result_type.kind == :type_lvalue_ref
              value_type = result_type.non_reference_type.spelling
              value_type_decl = result_type.non_reference_type.declaration
            else
              value_type = result_type.spelling
              value_type_decl = result_type.declaration
            end
            break
          end
        end

        return nil unless value_type  # Can't infer traits without operator*

        # Get fully qualified iterator type name from declaration
        # This works for non-std types since we skip std:: types above
        qualified_iterator = qualified_name

        # Get qualified value type from declaration if available
        qualified_value_type = value_type.sub(/\s*const\s*$/, '')  # Remove trailing const
        if value_type_decl && value_type_decl.kind != :cursor_no_decl_found
          qualified_value_type = value_type_decl.qualified_name
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

        @class_iterator_names[cursor.semantic_parent.cruby_name] << iterator_name

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

        qualified_parent = qualified_display_name_cpp(cursor.semantic_parent)
        self.render_cursor(cursor, "cxx_iterator_method", :name => iterator_name,
                           :begin_method => begin_method, :end_method => end_method,
                           :signature => signature,
                           :is_template => is_template,
                           :qualified_parent => qualified_parent)
      end

      def visit_conversion_function(cursor)
        # For now only deal with member functions
        return unless CURSOR_CLASSES.include?(cursor.lexical_parent.kind)

        return if skip_callable?(cursor)

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

        qualified_parent = qualified_display_name_cpp(cursor.semantic_parent)
        self.render_cursor(cursor, "conversion_function",
                           :ruby_name => ruby_name, :result_type => result_type_spelling,
                           :is_const => is_const,
                           :qualified_parent => qualified_parent)
      end

      def visit_enum_decl(cursor)
        return if CURSOR_CLASSES.include?(cursor.semantic_parent.kind) && !cursor.public?
        return if !cursor.anonymous? && skip_symbol?(cursor)

        if cursor.anonymous? && CURSOR_CLASSES.include?(cursor.semantic_parent.kind)
          # Anonymous enum inside a class — return constants as chainable strings
          versions = visit_children(cursor)
          return versions.values.flatten.map(&:strip)
        elsif cursor.anonymous?
          # Anonymous enum at namespace/TU level — return standalone constant definitions
          return render_children(cursor, strip: true)
        end

        under = find_under(cursor)
        children = render_children(cursor, indentation: 2, chain: true, terminate: true, strip: true)
        self.render_cursor(cursor, "enum_decl", :under => under, :children => children)
      end

      def visit_enum_constant_decl(cursor)
        return if skip_symbol?(cursor)
        self.render_cursor(cursor, "enum_constant_decl")
      end

      def visit_function(cursor)
        # Can't return arrays in C++
        return if cursor.type.result_type.is_a?(::FFI::Clang::Types::Array)
        return if skip_callable?(cursor)
        return if has_skipped_param_type?(cursor)
        return if has_skipped_return_type?(cursor)
        return unless has_export_macro?(cursor)

        if cursor.spelling.start_with?('operator') && !cursor.spelling.match?(/^operator\w/)
          return self.visit_operator_non_member(cursor)
        end

        name = cursor.ruby_name
        args = arguments(cursor)

        signature = method_signature(cursor)

        # Check if return type should use ReturnBuffer
        return_buffer = buffer_type?(cursor.type.result_type)

        under = cursor.ancestors_by_kind(:cursor_namespace)
                     .find { |a| !a.inline_namespace? }
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
        return if skip_symbol?(cursor)

        self.render_cursor(cursor, "constant",
                           :name => tokens.tokens[0].spelling.upcase_first,
                           :qualified_name => tokens.tokens[0].spelling)
      end

      def visit_namespace(cursor)
        # Skip anonymous namespaces - they're internal implementation details
        return if cursor.anonymous?

        # Inline namespaces (e.g., std::__1, abseil's lts_*) should not create
        # Ruby modules — their members belong to the enclosing namespace.
        # Recurse into children without registering a new module.
        if cursor.inline_namespace?
          return self.render_children(cursor)
        end

        result = Array.new

        # Don't redefine a namespace twice. It doesn't matter to Ruby, but C++ wrapper
        # will break with a redefinition error:
        #   Module rb_mNamespace = define_module("namespace");
        #   Module rb_mNamespace = define_module("namespace");
        qualified_display_name = cursor.qualified_display_name
        unless @namespaces.include?(qualified_display_name)
          @namespaces << qualified_display_name
          under = find_under(cursor)
          result << self.render_cursor(cursor, "namespace", :under => under)
        end

        result << self.render_children(cursor)

        result.map { |s| s.chomp }.reject(&:empty?).join("\n\n")
      end

      def visit_field_decl(cursor)
        return unless cursor.public?
        return if skip_symbol?(cursor)

        qualified_parent = qualified_display_name_cpp(cursor.semantic_parent)
        self.render_cursor(cursor, "field_decl",
                           :qualified_parent => qualified_parent)
      end

      def visit_operator_non_member(cursor)
        # This is a stand-alone operator, such as:
        #
        #   MatExpr operator + (const Mat& a, const Mat& b);  # binary (2 args)
        #   std::ostream& operator << (std::ostream& out, const Complex<_Tp>& c)
        #   MatExpr operator ~(const Mat& m);  # unary (1 arg)
        #   MatExpr operator -(const Mat& m);  # unary negation (1 arg)
        return if cursor.type.args_size < 1 || cursor.type.args_size > 2

        arg0_type = cursor.type.arg_type(0).non_reference_type
        class_cursor = arg0_type.declaration

        # Skip when the first argument is a fundamental type (e.g., double) or a
        # typedef to one (e.g., ptrdiff_t -> long long).  There is no Rice wrapper
        # for these types so Data_Type<T>() would be invalid.
        return if class_cursor.kind == :cursor_no_decl_found
        return if FUNDAMENTAL_TYPES.include?(arg0_type.canonical.kind)
        # Rice already provides bitwise operators (&, |, ^, ~, <<, >>) for enums automatically
        return if class_cursor.kind == :cursor_enum_decl

        # Skip types that Rice converts to native Ruby types (no Rice wrapper exists).
        # Note: std::vector, std::pair, etc. ARE wrapped by Rice.
        canonical_decl = arg0_type.canonical.declaration
        return if canonical_decl.kind != :cursor_no_decl_found &&
                  canonical_decl.location.in_system_header? &&
                  RICE_NATIVE_TYPES.include?(canonical_decl.spelling)

        # Use the class cursor directly - operators should be attached to the actual class
        # (e.g., rb_cCvMat for cv::Mat), not to typedefs (e.g., rb_cMatND which is typedef for Mat)
        # Collect non-member operators to render grouped by class later
        @non_member_operators[class_cursor.cruby_name] << { cursor: cursor, class_cursor: class_cursor }
        nil
      end

      def render_non_member_operators
        # Group operators by target class
        # Each entry stores { lines: [], cpp_type: string } for cross-file Data_Type<T>() usage
        grouped = Hash.new { |h, k| h[k] = { lines: [], cpp_type: nil } }

        @non_member_operators.each do |cruby_name, operators|
          operators.each do |op|
            cursor = op[:cursor]
            class_cursor = op[:class_cursor]

            # Handle ostream << specially - generates inspect method on the second arg's class
            arg0_decl = cursor.type.arg_type(0).non_reference_type.declaration
            if cursor.spelling.include?("<<") && arg0_decl.location.in_system_header? &&
               arg0_decl.spelling.end_with?("ostream")
              arg1_non_ref = cursor.type.arg_type(1).non_reference_type
              # Use Type#declaration to get the typedef/class cursor directly
              target_cursor = arg1_non_ref.declaration
              target_class = target_cursor.cruby_name
              arg_type = type_spelling(cursor.type.arg_type(1))
              grouped[target_class][:cpp_type] ||= qualified_class_name_cpp(target_cursor)
              grouped[target_class][:lines] << render_template("non_member_operator_inspect",
                                                               :arg_type => arg_type).strip
            elsif cursor.type.args_size == 1
              # Unary non-member operator (e.g., operator~(const Mat& m), operator-(const Mat& m))
              arg0_type = type_spelling(cursor.type.arg_type(0))
              result_type = type_spelling(cursor.result_type)
              op_symbol = cursor.spelling.sub(/^operator\s*/, '')
              # Ruby uses +@ and -@ for unary plus/minus, but ~ and ! stay as-is
              ruby_name = case op_symbol
                          when '+' then '+@'
                          when '-' then '-@'
                          else op_symbol
                          end

              grouped[cruby_name][:cpp_type] ||= qualified_class_name_cpp(class_cursor)
              grouped[cruby_name][:lines] << render_template("non_member_operator_unary",
                                                             :ruby_name => ruby_name,
                                                             :arg0_type => arg0_type,
                                                             :result_type => result_type,
                                                             :op_symbol => op_symbol).strip
            else
              # Binary non-member operator (e.g., operator+(const Mat& a, const Mat& b))
              arg0_type = type_spelling(cursor.type.arg_type(0))
              arg1_type = type_spelling(cursor.type.arg_type(1))
              result_type = type_spelling(cursor.result_type)
              op_symbol = cursor.spelling.sub(/^operator\s*/, '')
              ruby_name = cursor.ruby_name

              # Determine the appropriate return statement based on result type
              if cursor.result_type.kind == :type_void
                return_stmt = "self #{op_symbol} other;"
              elsif cursor.result_type.kind == :type_lvalue_ref &&
                    cursor.result_type.non_reference_type == cursor.type.arg_type(0).non_reference_type
                # Returns reference to self (e.g., FileStorage& operator<<)
                return_stmt = "self #{op_symbol} other;\n  return self;"
              else
                # Returns a value (e.g., bool, ptrdiff_t)
                return_stmt = "return self #{op_symbol} other;"
              end

              grouped[cruby_name][:cpp_type] ||= qualified_class_name_cpp(class_cursor)
              grouped[cruby_name][:lines] << render_template("non_member_operator_binary",
                                                             :ruby_name => ruby_name,
                                                             :arg0_type => arg0_type,
                                                             :arg1_type => arg1_type,
                                                             :result_type => result_type,
                                                             :return_stmt => return_stmt).strip
            end
          end
        end

        # Now render each group as a chained method call
        result = []
        grouped.each do |cruby_name, info|
          lines = info[:lines]
          cpp_type = info[:cpp_type]
          next if lines.empty?
          # Use variable for locally-defined classes, Data_Type<T>() for cross-file references
          class_ref = @classes.key?(cruby_name) ? cruby_name : "Data_Type<#{cpp_type}>()"
          # Join with method chaining, indented 4 spaces (2 for function body + 2 for method chain)
          content = merge_children({ nil => lines }, indentation: 4, chain: true, terminate: true, strip: true)
          result << "#{class_ref}#{content}"
        end
        result.join("\n  \n  ")
      end

      def visit_typedef_decl(cursor)
        return if cursor.semantic_parent.kind == :cursor_class_decl || cursor.semantic_parent.kind == :cursor_struct
        return if skip_symbol?(cursor)

        # Skip if already processed (can happen when force-generating base classes)
        return if @classes.key?(cursor.cruby_name)

        # Skip typedefs to std:: types - Rice handles these automatically
        canonical_decl = cursor.underlying_type.canonical.declaration
        return if canonical_decl.kind != :cursor_no_decl_found && canonical_decl.location.in_system_header?

        cursor_template_ref = cursor.find_first_by_kind(false, :cursor_template_ref)

        # Handle template case. For example:
        #   typedef Point_<int> Point2i;
        if cursor_template_ref
          # Skip if the template class is in symbols
          return if skip_symbol?(cursor_template_ref.referenced)

          visit_template_specialization(cursor, cursor_template_ref.referenced, cursor.underlying_type)
        else
          # Check for reference to template reference. For example:
          #   typedef Point2i Point;
          cursor_ref = cursor.find_first_by_kind(false, :cursor_type_ref)
          if cursor_ref
            cursor_template_ref = cursor_ref.referenced.find_first_by_kind(false, :cursor_template_ref)
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
        under = find_under(cursor)
        # Get template arguments including any default values that were omitted in the typedef
        template_arguments = get_full_template_arguments(underlying_type, cursor_template)

        result = ""

        # Is there a base class?
        base_ref = cursor_template.find_first_by_kind(false, :cursor_cxx_base_specifier)
        base_spelling = nil
        if base_ref
          # Base class children can be a :cursor_type_ref or :cursor_template_ref
          type_ref = base_ref.find_first_by_kind(false, :cursor_type_ref, :cursor_template_ref)
          base = type_ref.definition

          # Resolve the base class to its instantiated form (e.g., PtrStep<unsigned char>)
          base_spelling = resolve_base_instantiation(cursor, underlying_type)

          # Ensure the base class is generated before this class.
          # Skip std:: base classes — Rice handles standard library types automatically.
          # This prevents walking libstdc++ internals (e.g., cv::Ptr<T> inherits from
          # std::shared_ptr<T> → std::__shared_ptr<T> → std::__shared_ptr_access<T>).
          # Also check the base template's own namespace since resolve_base_instantiation
          # may incorrectly use the derived class's namespace (e.g., "cv::shared_ptr").
          base_template_decl = base_ref.find_first_by_kind(false, :cursor_type_ref, :cursor_template_ref)&.referenced
          base_in_std = base_template_decl&.location&.in_system_header?
          # Use cursor_template_ref specifically to get the base class template declaration
          # (cursor_type_ref may resolve to a template parameter like T instead)
          base_class_template = base_ref.find_first_by_kind(false, :cursor_template_ref)&.referenced
          base_in_current_file = base_class_template &&
            base_class_template.file_location.file == base_class_template.translation_unit.file.name
          if base_spelling && !base_in_std
            if base_in_current_file
              base_typedef = @typedef_map[base_spelling]
              if base_typedef
                # Base has a typedef - check if it has been generated yet
                unless @classes.key?(base_typedef.cruby_name)
                  # Force generate the typedef first (recursively handles its bases)
                  result = visit_typedef_decl(base_typedef) || ""
                end
              elsif !@auto_generated_bases.include?(base_spelling)
                # No typedef - auto-generate
                result = auto_generate_base_class(base_ref, base_spelling, template_arguments, under)
              end
            elsif base_class_template && !base_class_template.location.in_system_header?
              # Base template is from an included file — include its .ipp so the
              # _instantiate builder is available for the derived class
              builder_ipp = ipp_path_for_cursor(base_class_template)
              current_ipp = File.join(@relative_dir, "#{@basename}.ipp")
              if builder_ipp != current_ipp
                ipp_relative = Pathname.new(builder_ipp).relative_path_from(Pathname.new(@relative_dir)).to_s
                @includes << "#include \"#{ipp_relative}\""
              end
            end
          end
        end

        template_specialization = type_spelling(underlying_type)

        # If template is defined in a different file, include its .ipp for the _instantiate builder
        unless cursor_template.file_location.file == cursor_template.translation_unit.file.name
          builder_ipp = ipp_path_for_cursor(cursor_template)
          current_ipp = File.join(@relative_dir, "#{@basename}.ipp")
          if builder_ipp != current_ipp
            ipp_relative = Pathname.new(builder_ipp).relative_path_from(Pathname.new(@relative_dir)).to_s
            @includes << "#include \"#{ipp_relative}\""
          end
        end

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
      def auto_instantiate_template(cursor_template, instantiated_type, type, under)
        return "" unless cursor_template
        match = instantiated_type.match(/\<(.*)\>/)
        return "" unless match

        # Skip if template arguments reference skipped symbols
        return "" if type_references_skipped_symbol?(type)

        ruby_class_name = instantiated_type.gsub(/::|<|>|,|\s+/, ' ').split.map(&:capitalize).join
        ruby_class_name = @namer.apply_rename_types(ruby_class_name)
        cruby_name = "rb_c#{ruby_class_name}"
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
        @namer.apply_rename_types(base_name + args_name)
      end

      # Auto-generate a base class definition when no typedef exists for it.
      # When recursive: true, also generates any base classes of the base class.
      def auto_generate_base_class(base_ref, base_spelling, template_arguments, under, recursive: true)
        base_template_ref = base_ref.find_first_by_kind(false, :cursor_template_ref)
        return "" unless base_template_ref

        base_template = base_template_ref.referenced
        return "" if base_template.location.in_system_header?
        # Skip base templates from included files — their own output handles registration
        return "" unless base_template.file_location.file == base_template.translation_unit.file.name
        base_template_arguments = base_spelling.match(/<(.+)>\z/)&.[](1) || template_arguments
        return "" unless base_template_arguments

        result = ""
        base_base_spelling = nil

        # Check if this base class has its own base that needs auto-generation
        if recursive
          base_base_ref = base_template.find_first_by_kind(false, :cursor_cxx_base_specifier)
          if base_base_ref
            base_base_template_ref = base_base_ref.find_first_by_kind(false, :cursor_template_ref)
            if base_base_template_ref
              base_base_qualified_name = base_base_template_ref.referenced.qualified_name

              # Build substitution map from template params to actual values
              template_params = base_template.find_by_kind(false, :cursor_template_type_parameter,
                                                           :cursor_non_type_template_parameter).map(&:spelling)
              template_arg_values = split_template_args(base_template_arguments)
              subs = template_params.each_with_index.to_h { |param, i| [param, template_arg_values[i]] }

              # Substitute template parameters with actual values
              base_base_type_spelling = base_base_ref.type.spelling
              if base_base_type_spelling =~ /<(.+)>\z/
                base_base_args = split_template_args($1).map { |arg| subs[arg] || arg }.join(', ')
                base_base_spelling = "#{base_base_qualified_name}<#{base_base_args}>"

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
        return if skip_symbol?(cursor)

        result = Array.new

        # Define any embedded unions (skip anonymous/skipped ones that return nil)
        cursor.find_by_kind(false, :cursor_union) do |union|
          content = visit_union(union)
          result << content if content
        end

        # Define any embedded structures (skip anonymous/skipped ones that return nil)
        cursor.find_by_kind(false, :cursor_struct) do |struct|
          content = visit_struct(struct)
          result << content if content
        end

        under = find_under(cursor)

        children = render_children(cursor, indentation: 2, chain: true, terminate: true, strip: true,
                                           exclude_kinds: Set[:cursor_struct, :cursor_union])
        result << self.render_cursor(cursor, "union", :under => under, :children => children)
        result.map { |s| s.chomp }.join("\n\n")
      end

      def visit_variable(cursor)
        if CURSOR_CLASSES.include?(cursor.semantic_parent.kind) &&
          !cursor.public?
          return
        end
        return if skip_symbol?(cursor)

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
            qualified_parent = qualified_display_name_cpp(cursor.semantic_parent)
            self.render_cursor(cursor, "variable",
                               :qualified_parent => qualified_parent)
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

      def render_cursor(cursor, template, local_variables = {})
        render_template(template, local_variables.merge(:cursor => cursor))
      end

      # Returns [content, has_builders] where has_builders indicates if any builder templates were generated
      def render_class_templates(cursor, indentation: 0, strip: false)
        results = Array.new
        cursor.find_by_kind(true, :cursor_class_template) do |class_template_cursor|
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

          # Skip if explicitly listed in symbols
          if skip_symbol?(class_template_cursor)
            next :continue
          end

          results << visit_class_template_builder(class_template_cursor)
        end
        content = merge_children({ nil => results }, indentation: indentation, strip: strip)
        has_builders = !results.empty? && !content.strip.empty?
        [content, has_builders]
      end

      def visit_children(cursor, exclude_kinds: Set.new, only_kinds: nil)
        versions = Hash.new { |h, k| h[k] = [] }
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

          child_kind = child_cursor.kind

          unless child_cursor.declaration? || child_kind == :cursor_macro_definition
            next :continue
          end

          if child_cursor.forward_declaration?
            next :continue
          end

          if exclude_kinds.include?(child_kind)
            next :continue
          end

          if only_kinds && !only_kinds.include?(child_kind)
            next :continue
          end

          visit_method = "visit_#{child_kind.to_s.delete_prefix("cursor_").underscore}".to_sym
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

      def merge_children(versions, indentation: 0, chain: false, terminate: false, strip: false)
        lines = versions.keys.sort_by { |key| key.to_s }.each_with_object([]) do |version, result|
          next unless versions[version]&.any?
          result << "#if #{@version_check} >= #{version}" if version
          versions[version].each do |line|
            line = line.rstrip if strip
            line = ".#{line}" if chain
            result << line
          end
          result << "#endif\n" if version
        end

        if lines.empty?
          return terminate ? ";" : ""
        end

        result = if chain
                   lines.join("\n")
                 else
                   lines.map { |l| l.chomp }.reject(&:empty?).join("\n\n")
                 end
        if terminate
          result += ";"
        end

        result = add_indentation(result, indentation) if indentation > 0
        result = "\n" + result if chain || terminate
        result
      end

      def render_children(cursor, indentation: 0, chain: false, terminate: false, strip: false,
                          exclude_kinds: Set.new, only_kinds: nil)
        versions = visit_children(cursor, exclude_kinds: exclude_kinds, only_kinds: only_kinds)
        merge_children(versions, indentation: indentation, chain: chain, terminate: terminate, strip: strip)
      end

      # Build maps for type lookups:
      # - @typedef_map: canonical type spellings -> typedef/using declarations
      #   Includes all files (not just main) because base classes may have typedefs in included headers
      # - @type_name_map: simple name -> qualified name for classes, templates, and typedefs
      #   Used by qualify_template_args to namespace-qualify names in template arguments
      def build_typedef_map(cursor)
        cursor.find_by_kind(true, :cursor_typedef_decl, :cursor_type_alias_decl,
                            :cursor_class_template, :cursor_class_decl, :cursor_struct) do |child|
          case child.kind
          when :cursor_typedef_decl, :cursor_type_alias_decl
            # Skip typedefs inside classes/structs (like DataType<T>::value_type)
            parent_kind = child.semantic_parent.kind
            next if parent_kind == :cursor_class_decl || parent_kind == :cursor_struct ||
                    parent_kind == :cursor_class_template || parent_kind == :cursor_class_template_partial_specialization
            canonical = child.underlying_type.canonical.spelling
            existing = @typedef_map[canonical]
            # Prefer non-std typedefs over std ones (e.g., cv::String over std::string)
            if existing.nil? || (existing.qualified_name.start_with?("std::") && !child.qualified_name.start_with?("std::"))
              @typedef_map[canonical] = child
            end
            # Also add to type_name_map for qualifying unqualified names in type spellings
            # (e.g., "String" -> "cv::String" for std::map<String, Value>::iterator)
            simple_name = child.spelling
            qualified_name = child.qualified_name
            if simple_name != qualified_name && !simple_name.empty?
              # Prefer non-std over std (consistent with typedef_map preference)
              existing_qualified = @type_name_map[simple_name]
              if existing_qualified.nil? || (existing_qualified.start_with?("std::") && !qualified_name.start_with?("std::"))
                @type_name_map[simple_name] = qualified_name
              end
            end
          when :cursor_class_template, :cursor_class_decl, :cursor_struct
            # Collect class/struct names for qualifying template arguments.
            # Needed for non-type template args like Config::Size where Config is a
            # regular class (not a template) that needs namespace qualification.
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
        template_ref = cursor.find_first_by_kind(false, :cursor_template_ref)
        return nil unless template_ref

        derived_template = template_ref.referenced

        # Get base specifier from the template
        base_spec = derived_template.find_first_by_kind(false, :cursor_cxx_base_specifier)
        return nil unless base_spec

        # Get the template reference in the base specifier
        base_template_ref = base_spec.find_first_by_kind(false, :cursor_template_ref)

        # If there's no template ref, the base class is a non-template class (e.g., Mat_<_Tp> : public Mat)
        unless base_template_ref
          base_type_ref = base_spec.find_first_by_kind(false, :cursor_type_ref)
          return base_type_ref&.referenced&.qualified_name
        end

        # Extract template arguments from the canonical spelling of the typedef
        canonical = underlying_type.canonical.spelling
        return nil unless canonical =~ /<(.+)>\z/

        template_args_str = $1

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
        base_name = base_template_ref.referenced.qualified_name
        resolved_args = base_args.join(', ')
        "#{base_name}<#{resolved_args}>"
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
