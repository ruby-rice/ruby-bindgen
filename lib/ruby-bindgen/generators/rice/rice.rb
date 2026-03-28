require 'set'
require_relative 'reference_qualifier'
require_relative 'signature_builder'
require_relative 'template_resolver'
require_relative 'type_index'
require_relative 'type_speller'

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

      # Directory containing the ERB templates used by the Rice generator.
      def self.template_dir
        __dir__
      end

      # Create the main generator plus the extracted helpers that own naming,
      # qualification, template resolution, and signature construction.
      def initialize(inputter, outputter, config)
        super(inputter, outputter, config)
        @include_header = config[:include]
        @init_names = Hash.new
        @namespaces = Set.new
        @classes = Hash.new  # Maps cruby_name -> C++ type for Data_Type<T> declarations
        @reference_qualifier = ReferenceQualifier.new
        @type_index = TypeIndex.new
        @type_speller = TypeSpeller.new(type_index: @type_index)
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
        @template_resolver = TemplateResolver.new(reference_qualifier: @reference_qualifier,
                                                  type_speller: @type_speller,
                                                  namer: @namer)
        @signature_builder = SignatureBuilder.new(type_speller: @type_speller,
                                                  reference_qualifier: @reference_qualifier,
                                                  copyable_type: method(:copyable_type?),
                                                  cursor_literals: CURSOR_LITERALS,
                                                  fundamental_types: FUNDAMENTAL_TYPES)
        # Non-member operators grouped by target class cruby_name
        @non_member_operators = Hash.new { |h, k| h[k] = [] }
        # Iterators that need std::iterator_traits specialization
        @incomplete_iterators = Hash.new
        # Iterator names per class (for aliasing each_const -> each)
        @class_iterator_names = Hash.new { |h, k| h[k] = Set.new }
      end

      # Parse the configured inputs with libclang and stream the resulting
      # translation units back through this visitor.
      def generate
        clang_args = @config[:clang_args] || []
        parser = RubyBindgen::Parser.new(@inputter, clang_args, libclang: @config[:libclang])
        ::FFI::Clang::Cursor.namer = @namer
        parser.generate(self)
      end

      # Check if a type references a skipped symbol by examining its declaration.
      # Unwraps pointers/references and checks template arguments recursively.
      def type_references_skipped_symbol?(type)
        type = unwrapped_indirection_type(type)

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

      # Rice bindings cannot sensibly expose callable parameters that require
      # move-only / rvalue-reference semantics.
      def has_unsupported_rice_param_type?(cursor)
        (0...cursor.type.args_size).any? do |i|
          type = cursor.type.arg_type(i)
          type.kind == :type_rvalue_ref ||
            unsupported_rice_callback_type?(type) ||
            unsupported_rice_opaque_namespace_type?(type)
        end
      end

      def has_unsupported_rice_return_type?(cursor)
        result_type = cursor.type.result_type
        unsupported_rice_opaque_namespace_type?(result_type)
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

      # Rice's std::function adapter is not reliable once callback signatures
      # involve references or nested callbacks which themselves do. Skip those
      # attrs instead of emitting uncompilable wrappers.
      def unsupported_rice_attribute_type?(type)
        reference_type?(type) ||
          unsupported_rice_callback_type?(type)
      end

      # Namespace-scope forward declarations can be compile-time traps for Rice
      # when methods expose them by value/reference but no complete definition is
      # available (for example optional backend types like plaidml::edsl::Tensor).
      # Keep nested pimpl-style forward declarations on the existing path.
      def unsupported_rice_opaque_namespace_type?(type)
        return false if [:type_pointer, :type_member_pointer].include?(type.kind)
        return false if type.spelling.start_with?("std::")

        type = type.non_reference_type if reference_type?(type)
        return false if type.spelling.include?("<") || type.canonical.spelling.include?("<")

        decl = type.canonical.declaration
        return false if decl.kind == :cursor_no_decl_found
        return false unless decl.opaque_declaration?
        return false if decl.qualified_name&.start_with?("std::", "__gnu_cxx::")
        return false if [:cursor_class_decl, :cursor_struct].include?(decl.semantic_parent.kind)

        true
      end

      def unsupported_rice_vector_element_type?(type)
        type = type.non_reference_type if reference_type?(type)
        canonical = type.canonical
        decl = canonical.declaration
        return false if decl.kind == :cursor_no_decl_found
        return false unless vector_like_type?(decl)

        element_type = canonical.template_argument_type(0)
        return false if element_type.nil? || element_type.kind == :type_invalid

        !rice_equality_supported?(element_type)
      end

      def vector_like_type?(decl)
        decl.spelling == "vector" || decl.qualified_name == "std::vector"
      end

      def variant_like_type?(decl)
        decl.spelling == "variant" || decl.qualified_name&.end_with?("::variant")
      end

      def rice_equality_supported?(type)
        type = type.non_reference_type if reference_type?(type)
        type = type.canonical

        return true if FUNDAMENTAL_TYPES.include?(type.kind) || type.kind == :type_enum
        return true if [:type_pointer, :type_member_pointer].include?(type.kind)

        decl = type.declaration
        return true if decl.kind == :cursor_no_decl_found
        return true if comparable_std_type?(decl)

        if variant_like_type?(decl)
          return (0...type.num_template_arguments).all? do |i|
            arg_type = type.template_argument_type(i)
            next true if arg_type.kind == :type_invalid

            rice_equality_supported?(arg_type)
          end
        end

        has_equality_operator?(decl)
      end

      def comparable_std_type?(decl)
        ["basic_string", "string", "monostate"].include?(decl.spelling) ||
          ["std::string", "std::monostate"].include?(decl.qualified_name)
      end

      def has_equality_operator?(decl)
        return true if decl.find_by_kind(false, :cursor_cxx_method).any? do |method|
          method.spelling == "operator==" && method.type.args_size == 1
        end

        @translation_unit_cursor.find_by_kind(true, :cursor_function, :cursor_function_template).any? do |function|
          next false unless function.spelling == "operator=="
          next false unless function.type.args_size == 2

          arg_declarations = 2.times.map do |index|
            unwrapped_indirection_type(function.type.arg_type(index)).canonical.declaration
          end

          arg_declarations.all? do |arg_decl|
            arg_decl.kind != :cursor_no_decl_found &&
              (arg_decl == decl || arg_decl.qualified_name == decl.qualified_name)
          end
        end
      end

      def unsupported_rice_callback_type?(type)
        type = type.non_reference_type if reference_type?(type)
        canonical = type.canonical
        decl = canonical.declaration
        return false if decl.kind == :cursor_no_decl_found
        return false unless decl.qualified_name == "std::function"

        callback_signature_unsupported?(canonical.template_argument_type(0))
      end

      def callback_signature_unsupported?(type)
        return false if type.nil? || type.kind == :type_invalid
        return false unless [:type_function_proto, :type_function_no_proto].include?(type.kind)

        return true if reference_type?(type.result_type)

        type.arg_types.any? do |arg_type|
          reference_type?(arg_type) || unsupported_rice_callback_type?(arg_type)
        end
      end

      def implicit_default_constructor_available?(cursor)
        cursor.find_by_kind(false, :cursor_field_decl).none? do |field|
          reference_type?(field.type)
        end
      end

      # Reset any per-run caches before parsing begins.
      def visit_start
        # Clear caches from previous runs
        @type_speller.clear
      end

      def visit_parse_error(_path, relative_path, error)
        warn "Warning: skipping #{relative_path} because it could not be parsed"
        warn error.message
      end

      # Emit the shared include header and optional project wrapper once all
      # translation units have been processed.
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

      # Render one translation unit into its generated `-rb.hpp`, `-rb.cpp`, and
      # optional `-rb.ipp` outputs.
      def visit_translation_unit(translation_unit, path, relative_path)
        @namespaces.clear
        @classes.clear
        @auto_generated_bases.clear
        @non_member_operators.clear
        @incomplete_iterators.clear
        @class_iterator_names.clear
        @declared_function_qualified_names = nil
        cursor = translation_unit.cursor
        @translation_unit_cursor = cursor
        @type_speller.printing_policy = cursor.printing_policy

        # Build lookups for typedef resolution and simple-name qualification.
        @type_index.build!(cursor)

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

      # Render a public, callable constructor into the Rice chain for its class.
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
        return if has_unsupported_rice_param_type?(cursor)

        signature = @signature_builder.constructor_signature(cursor)
        args = @signature_builder.arguments(cursor)

        return unless signature

        self.render_cursor(cursor, "constructor",
                           :signature => signature, :args => args)
      end

      # Render a class or struct, including child members, anonymous enum
      # constants, embedded types, and any auto-generated template bases needed
      # before the class itself can be registered.
      def visit_class_decl(cursor)
        # Namespace-scope forward-declared C++ classes are often completed in a
        # different header. Emitting a Rice class here creates a Ruby constant
        # with no superclass, and a later complete definition then conflicts.
        # Keep nested incomplete classes on the existing special path, and keep
        # opaque structs available for handle-style APIs.
        if cursor.kind == :cursor_class_decl &&
           cursor.opaque_declaration? &&
           ![:cursor_class_decl, :cursor_struct].include?(cursor.semantic_parent.kind)
          return
        end

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
        if !cursor.abstract? &&
           !cursor.opaque_declaration? &&
           constructors.none? &&
           implicit_default_constructor_available?(cursor)
          versions[nil].unshift(self.render_template("constructor",
                                                     :cursor => cursor,
                                                     :signature => @signature_builder.constructor_signature(cursor),
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
        cpp_type = @type_speller.qualified_class_name(cursor)
        raw_class_name = cursor.type.spelling.split("::").last
        ruby_class_name = @namer.apply_rename_types(raw_class_name, raw_class_name.camelize)
        has_incomplete_classes = !incomplete_classes_content.to_s.empty?
        @classes[cursor.cruby_name] = cpp_type
        result[nil] << self.render_cursor(cursor, "class", :under => under, :base => base,
                                     :auto_generated_base => auto_generated_base,
                                     :incomplete_classes => incomplete_classes_content,
                                     :children => children_content,
                                     :cpp_type => cpp_type,
                                     :ruby_class_name => ruby_class_name,
                                     :has_incomplete_classes => has_incomplete_classes)

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
            type = unwrapped_indirection_type(param.type)

            # Skip if not a template instantiation or is from a system header (std::, etc.)
            next unless type.num_template_arguments > 0
            next if type.canonical.declaration.location.in_system_header?

            # Find the class template declaration semantically so alias parameters
            # like `using AliasContainer = Container<Item>` still auto-instantiate
            # the underlying `Container<Item>` specialization.
            decl, instantiated_type, instantiated_type_source = parameter_template_instantiation(type, param)
            next unless decl && decl.kind == :cursor_class_template
            next unless (decl.location.file == cursor.location.file rescue false)

            # Auto-instantiate if no typedef exists
            instantiated_type = @type_speller.qualify_class_static_members(instantiated_type, cursor)
            next if @type_index.typedef_for(instantiated_type)

            code = auto_instantiate_template(decl, instantiated_type, instantiated_type_source, under)
            result << code unless code.empty?
          end
        end

        merge_children({ nil => result })
      end

      # Resolve the actual class template being instantiated for a parameter type.
      # This prefers semantic specialization data so aliases such as
      # `using AliasContainer = Container<Item>` still resolve to `Container`.
      def parameter_template_instantiation(type, param)
        declaration = type.declaration
        specialized_template = declaration.specialized_template
        unless specialized_template.kind == :cursor_invalid_file
          return [specialized_template, @type_speller.type_spelling(type.unqualified_type), type]
        end

        canonical_type = type.canonical
        canonical_declaration = canonical_type.declaration
        specialized_template = canonical_declaration.specialized_template
        unless specialized_template.kind == :cursor_invalid_file
          return [specialized_template, @type_speller.type_spelling(canonical_type.unqualified_type), canonical_type]
        end

        template_ref = param.find_first_by_kind(true, :cursor_template_ref)
        return [nil, nil, type] unless template_ref

        [template_ref.referenced, @type_speller.type_spelling(type.unqualified_type), type]
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

        base_declaration = base_specifier.type&.declaration
        return nil unless base_declaration && base_declaration.kind != :cursor_no_decl_found

        specialized_template = base_declaration.specialized_template
        base_cursor = specialized_template.kind == :cursor_invalid_file ? base_declaration : specialized_template

        # Skip system-header base classes (e.g., std::shared_ptr)
        return nil if base_cursor.location.in_system_header?

        @template_resolver.resolve_base_specifier_spelling(base_specifier)
      end

      # Render the reusable `_instantiate` helper for a class template so typedefs
      # and alias specializations can bind that template later.
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

        raw_template_parameters = cursor.find_by_kind(false, *template_parameter_kinds)

        # Filter out unnamed template parameters (e.g., `typename = void` default params)
        # — they have empty spelling and produce invalid C++ like `<T, >`
        template_parameters = raw_template_parameters.reject { |p| p.spelling.empty? }
        return if template_parameters.empty? && raw_template_parameters.any?
        template_signature = template_parameters.map { |template_parameter| @template_resolver.template_parameter_signature(template_parameter) }
                                               .join(", ")

        # Build fully qualified type using template params (e.g., Tests::Matrix<T, Rows, Columns>)
        param_names = template_parameters.map { |template_parameter| @template_resolver.template_parameter_argument(template_parameter) }
                                        .join(", ")
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
        type = type.non_reference_type if reference_type?(type)

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

      ITERATOR_METHODS = ["begin", "end", "cbegin", "cend", "rbegin", "rend", "crbegin", "crend"].freeze

      # Common skip checks for functions and methods
      def skip_callable?(cursor)
        skip_symbol?(cursor) ||
          cursor.availability == :deprecated ||
          cursor.type.variadic?
      end

      def unresolved_inline_calls?(cursor)
        source = inline_definition_source(cursor)
        return false unless source&.include?('{')

        function_calls = source.scan(/([A-Za-z_]\w*(?:::[A-Za-z_]\w*)+)\s*\(/)
                               .flatten
                               .uniq
                               .select { |name| name.split('::').last.match?(/\A[a-z_]\w*\z/) }
        return false if function_calls.empty?

        function_calls.any? do |qualified_name|
          !declared_function_qualified_names.include?(qualified_name)
        end
      end

      # Render a class method, including special handling for iterator adapters
      # and mutable `operator[]` setter support.
      def visit_cxx_method(cursor)
        # Do not process method definitions outside of classes (because we already processed them)
        return if cursor.lexical_parent != cursor.semantic_parent
        return if skip_callable?(cursor)
        return if unresolved_inline_calls?(cursor)
        return if has_skipped_param_type?(cursor)
        return if has_unsupported_rice_param_type?(cursor)
        return if has_skipped_return_type?(cursor)
        return if has_unsupported_rice_return_type?(cursor)

        # Is this an iterator?
        if ITERATOR_METHODS.include?(cursor.spelling)
          return visit_cxx_iterator_method(cursor)
        end

        signature = @signature_builder.method_signature(cursor)

        result = Array.new

        name = cursor.ruby_name
        args = @signature_builder.arguments(cursor)

        # Check if return type should use ReturnBuffer
        return_buffer = @signature_builder.buffer_type?(cursor.result_type)

        is_template = cursor.semantic_parent.kind == :cursor_class_template
        qualified_parent = @type_speller.qualified_display_name(cursor.semantic_parent)
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
          index_type = @type_speller.type_spelling(cursor.type.arg_type(0))
          index_name = index_param&.spelling.to_s.empty? ? "index" : index_param.spelling
          value_type = @type_speller.type_spelling(cursor.result_type)
          result << self.render_cursor(cursor, "operator[]",
                                       :name => name,
                                       :index_type => index_type,
                                       :index_name => index_name,
                                       :qualified_parent => qualified_parent,
                                       :value_type => value_type)
        end
        result
      end

      def declared_function_qualified_names
        @declared_function_qualified_names ||= @translation_unit_cursor
          .find_by_kind(true, :cursor_function, :cursor_function_template)
          .map(&:qualified_name)
          .reject(&:empty?)
          .to_set
      end

      def inline_definition_source(cursor)
        parent = cursor.semantic_parent
        source = parent&.extent&.text
        return nil if source.nil? || source.empty?

        line_index = cursor.extent.start.line - parent.extent.start.line
        lines = source.lines
        return nil if line_index.negative? || line_index >= lines.length

        result = String.new
        brace_depth = 0
        saw_body = false

        lines[line_index..].each do |line|
          result << line
          line.each_char do |char|
            if char == '{'
              saw_body = true
              brace_depth += 1
            elsif char == '}'
              brace_depth -= 1 if brace_depth.positive?
            end
          end

          break if saw_body && brace_depth.zero?
          break if !saw_body && line.include?(';')
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
        signature = @signature_builder.method_signature(cursor)
        is_template = cursor.semantic_parent.kind == :cursor_class_template

        return unless signature

        # Check if iterator needs std::iterator_traits specialization
        iterator_type = cursor.result_type
        traits = check_iterator_traits(iterator_type)
        if traits
          # Record this iterator for traits generation (use type as key to avoid duplicates)
          @incomplete_iterators[traits[:iterator_type]] = traits
        end

        qualified_parent = @type_speller.qualified_display_name(cursor.semantic_parent)
        self.render_cursor(cursor, "cxx_iterator_method", :name => iterator_name,
                           :begin_method => begin_method, :end_method => end_method,
                           :signature => signature,
                           :is_template => is_template,
                           :qualified_parent => qualified_parent)
      end

      # Render a conversion operator such as `operator bool()` or `operator T*()`.
      # Template-parameter conversions that cannot produce stable Ruby names are skipped.
      def visit_conversion_function(cursor)
        # For now only deal with member functions
        return unless CURSOR_CLASSES.include?(cursor.lexical_parent.kind)

        return if skip_callable?(cursor)

        return unless cursor.type.args_size == 0
        return if has_skipped_return_type?(cursor)
        return if has_unsupported_rice_return_type?(cursor)

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

        result_type_spelling = @type_speller.type_spelling(result_type)
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

        qualified_parent = @type_speller.qualified_display_name(cursor.semantic_parent)
        self.render_cursor(cursor, "conversion_function",
                           :ruby_name => ruby_name, :result_type => result_type_spelling,
                           :is_const => is_const,
                           :qualified_parent => qualified_parent)
      end

      # Render a named enum as a Rice enum, or flatten anonymous enum constants
      # into the surrounding class/namespace output.
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

      # Render one enum constant, preserving whether it came from an anonymous
      # enum and whether that enum lives inside a class scope.
      def visit_enum_constant_decl(cursor)
        return if skip_symbol?(cursor)
        enum_parent = cursor.semantic_parent
        enum_scope = enum_parent.semantic_parent
        anonymous_parent = enum_parent.anonymous?
        anonymous_class_scope = anonymous_parent &&
          [:cursor_class_decl, :cursor_struct, :cursor_class_template].include?(enum_scope.kind)
        qualified_name = "#{@type_speller.qualified_display_name(enum_scope)}::#{cursor.spelling}"

        self.render_cursor(cursor, "enum_constant_decl",
                           :anonymous_parent => anonymous_parent,
                           :anonymous_class_scope => anonymous_class_scope,
                           :owner_cruby_name => enum_scope.cruby_name,
                           :qualified_name => qualified_name,
                           :value_name => cursor.qualified_display_name)
      end

      # Render a free function or non-member operator that survives the symbol,
      # export-macro, and parameter/return-type filters.
      def visit_function(cursor)
        # Can't return arrays in C++
        return if cursor.type.result_type.is_a?(::FFI::Clang::Types::Array)
        return if skip_callable?(cursor)
        return if has_skipped_param_type?(cursor)
        return if has_unsupported_rice_param_type?(cursor)
        return if has_skipped_return_type?(cursor)
        return if has_unsupported_rice_return_type?(cursor)
        return unless has_export_macro?(cursor)

        if cursor.spelling.start_with?('operator') && !cursor.spelling.match?(/^operator\w/)
          return self.visit_operator_non_member(cursor)
        end

        name = cursor.ruby_name
        args = @signature_builder.arguments(cursor)

        signature = @signature_builder.method_signature(cursor)

        # Check if return type should use ReturnBuffer
        return_buffer = @signature_builder.buffer_type?(cursor.type.result_type)

        under = cursor.ancestors_by_kind(:cursor_namespace)
                     .find { |a| !a.inline_namespace? }
        self.render_cursor(cursor, "function",
                           :under => under,
                           :name => name,
                           :signature => signature,
                           :args => args,
                           :return_buffer => return_buffer)
      end

      # Render simple object-like macros as Ruby constants when the macro body is
      # exactly one literal token.
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

      # Render a namespace as a Ruby module, except for inline namespaces which
      # are flattened into their enclosing namespace.
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

      # Render a public field as a Rice attribute on its containing class.
      def visit_field_decl(cursor)
        return unless cursor.public?
        return if skip_symbol?(cursor)
        return if unsupported_rice_attribute_type?(cursor.type)

        qualified_parent = @type_speller.qualified_display_name(cursor.semantic_parent)
        self.render_cursor(cursor, "field_decl",
                           :qualified_parent => qualified_parent)
      end

      # Record a free operator for later rendering onto the target class.
      # These are grouped and emitted after normal members so cross-file
      # `Data_Type<T>()` references can be handled in one pass.
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

      # Render the queued non-member operators grouped by their target class.
      # This includes ostream-based `inspect`, unary operators, and binary operators.
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
              arg_type = @type_speller.type_spelling(cursor.type.arg_type(1))
              grouped[target_class][:cpp_type] ||= @type_speller.qualified_class_name(target_cursor)
              grouped[target_class][:lines] << render_template("non_member_operator_inspect",
                                                               :arg_type => arg_type).strip
            elsif cursor.type.args_size == 1
              # Unary non-member operator (e.g., operator~(const Mat& m), operator-(const Mat& m))
              arg0_type = @type_speller.type_spelling(cursor.type.arg_type(0))
              result_type = @type_speller.type_spelling(cursor.result_type)
              op_symbol = cursor.spelling.sub(/^operator\s*/, '')
              # Ruby uses +@ and -@ for unary plus/minus, but ~ and ! stay as-is
              ruby_name = case op_symbol
                          when '+' then '+@'
                          when '-' then '-@'
                          else op_symbol
                          end

              grouped[cruby_name][:cpp_type] ||= @type_speller.qualified_class_name(class_cursor)
              grouped[cruby_name][:lines] << render_template("non_member_operator_unary",
                                                             :ruby_name => ruby_name,
                                                             :arg0_type => arg0_type,
                                                             :result_type => result_type,
                                                             :op_symbol => op_symbol).strip
            else
              # Binary non-member operator (e.g., operator+(const Mat& a, const Mat& b))
              arg0_type = @type_speller.type_spelling(cursor.type.arg_type(0))
              arg1_type = @type_speller.type_spelling(cursor.type.arg_type(1))
              result_type = @type_speller.type_spelling(cursor.result_type)
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

              grouped[cruby_name][:cpp_type] ||= @type_speller.qualified_class_name(class_cursor)
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

      # Resolve a top-level typedef or alias to the class template specialization
      # it names, then render the specialization binding.
      def visit_typedef_decl(cursor)
        return if cursor.semantic_parent.kind == :cursor_class_decl || cursor.semantic_parent.kind == :cursor_struct
        return if skip_symbol?(cursor)

        # Skip if already processed (can happen when force-generating base classes)
        return if @classes.key?(cursor.cruby_name)

        # Skip typedefs to std:: types - Rice handles these automatically
        canonical_decl = cursor.underlying_type.canonical.declaration
        return if canonical_decl.kind != :cursor_no_decl_found && canonical_decl.location.in_system_header?

        template_specialization = template_specialization_target(cursor)
        return unless template_specialization

        cursor_template, underlying_type = template_specialization
        return if skip_symbol?(cursor_template)

        visit_template_specialization(cursor, cursor_template, underlying_type)
      end

      # Handle C++11 'using' type alias declarations the same as typedef
      def visit_type_alias_decl(cursor)
        visit_typedef_decl(cursor)
      end

      # Resolve a typedef or type alias to the class template specialization it names.
      # Handles both direct specializations:
      #   typedef Point_<int> Point2i;
      # and aliases through an existing typedef:
      #   typedef Point2i Point;
      def template_specialization_target(cursor)
        type = cursor.underlying_type

        loop do
          declaration = type.declaration
          return nil if declaration.kind == :cursor_no_decl_found

          template_cursor = declaration.specialized_template
          return [template_cursor, type] unless template_cursor.kind == :cursor_invalid_file

          return nil unless declaration.kind == :cursor_typedef_decl || declaration.kind == :cursor_type_alias_decl

          type = declaration.underlying_type
        end
      end

      # Render one typedef/alias specialization of a class template and ensure
      # any inherited template bases are available first.
      def visit_template_specialization(cursor, cursor_template, underlying_type)
        under = find_under(cursor)
        # Get template arguments including any default values that were omitted in the typedef
        template_argument_values = @template_resolver.full_template_arguments(cursor, underlying_type, cursor_template)
        template_arguments = template_argument_values.join(", ")

        result = ""

        # Is there a base class?
        base_ref = cursor_template.find_first_by_kind(false, :cursor_cxx_base_specifier)
        base_spelling = nil
        if base_ref
          # Base class children can be a :cursor_type_ref or :cursor_template_ref
          type_ref = base_ref.find_first_by_kind(false, :cursor_type_ref, :cursor_template_ref)
          base = type_ref.definition

          # Resolve the base class to its instantiated form (e.g., PtrStep<unsigned char>)
          base_spelling = @template_resolver.resolve_base_instantiation(cursor, underlying_type)

          # Ensure the base class is generated before this class.
          # Skip std:: base classes — Rice handles standard library types automatically.
          # This prevents walking libstdc++ internals (e.g., cv::Ptr<T> inherits from
          # std::shared_ptr<T> → std::__shared_ptr<T> → std::__shared_ptr_access<T>).
          # Also check the base template's own namespace since resolve_base_instantiation
          # may incorrectly use the derived class's namespace (e.g., "cv::shared_ptr").
          base_template_decl = template_cursor_definition(base_ref.find_first_by_kind(false, :cursor_type_ref, :cursor_template_ref)&.referenced)
          base_in_std = base_template_decl&.location&.in_system_header?
          # Use cursor_template_ref specifically to get the base class template declaration
          # (cursor_type_ref may resolve to a template parameter like T instead)
          base_class_template = template_cursor_definition(base_ref.find_first_by_kind(false, :cursor_template_ref)&.referenced)
          base_in_current_file = base_class_template &&
            translation_unit_file?(base_class_template)
          if base_spelling && !base_in_std
            if base_in_current_file
              base_typedef = @type_index.typedef_for(base_spelling)
              if base_typedef
                # Base has a typedef - check if it has been generated yet
                unless @classes.key?(base_typedef.cruby_name)
                  # Force generate the typedef first (recursively handles its bases)
                  result = visit_typedef_decl(base_typedef) || ""
                end
              elsif !@auto_generated_bases.include?(base_spelling)
                # No typedef - auto-generate
                result = auto_generate_base_class(base_ref, base_spelling, under)
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

        template_specialization = @template_resolver.specialization_spelling(cursor, underlying_type, cursor_template)

        # If template is defined in a different file, include its .ipp for the _instantiate builder
        template_owner = template_cursor_definition(cursor_template)
        unless translation_unit_file?(template_owner)
          builder_ipp = ipp_path_for_cursor(template_owner)
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

      # Auto-generate a base class definition when no typedef exists for it.
      # When recursive: true, also generates any base classes of the base class.
      def auto_generate_base_class(base_ref, base_spelling, under, recursive: true)
        base_template_ref = base_ref.find_first_by_kind(false, :cursor_template_ref)
        return "" unless base_template_ref

        base_declaration = base_ref.type.declaration
        unless base_declaration.kind == :cursor_no_decl_found
          specialized_template = base_declaration.specialized_template
          return "" if specialized_template.kind == :cursor_class_template_partial_specialization
        end

        base_template = base_template_ref.referenced
        return "" if base_template.location.in_system_header?
        return "" if base_template.kind == :cursor_class_template_partial_specialization
        # Skip base templates from included files — their own output handles registration
        return "" unless translation_unit_file?(base_template)
        base_template_arguments_text = @template_resolver.template_argument_list_text(base_spelling)
        return "" unless base_template_arguments_text

        base_template_arguments = @template_resolver.template_argument_texts(base_template_arguments_text)
        return "" if base_template_arguments.empty?

        result = ""
        base_base_spelling = nil

        # Check if this base class has its own base that needs auto-generation
        if recursive
          base_base_ref = base_template.find_first_by_kind(false, :cursor_cxx_base_specifier)
          if base_base_ref
            base_base_template_ref = base_base_ref.find_first_by_kind(false, :cursor_template_ref)
            if base_base_template_ref
              # Build substitution map from template params to actual values
              template_params = @template_resolver.template_parameters(base_template).map(&:spelling)
              template_arg_values = base_template_arguments
              subs = template_params.each_with_index.to_h { |param, i| [param, template_arg_values[i]] }

              # Substitute template parameters with actual values
              base_base_spelling = @template_resolver.resolve_base_specifier_spelling(base_base_ref, substitutions: subs)

              if base_base_spelling && !@type_index.typedef_for(base_base_spelling) && !@auto_generated_bases.include?(base_base_spelling)
                result = auto_generate_base_class(base_base_ref, base_base_spelling, under)
              end
            end
          end
        end

        @auto_generated_bases << base_spelling
        ruby_name = @template_resolver.ruby_name_from_template(base_spelling, base_template_arguments)
        cruby_name = "rb_c#{ruby_name}"

        @classes[cruby_name] = base_spelling
        result + render_template("auto_generated_base_class",
                        :cruby_name => cruby_name, :ruby_name => ruby_name,
                        :base_spelling => base_spelling, :base_base_spelling => base_base_spelling,
                        :base_template => base_template, :template_arguments => base_template_arguments_text,
                        :under => under)
      end

      # Auto-generate a template base class for a non-template derived class.
      # For example: class PlaneWarper : public WarperBase<PlaneProjector>
      def auto_generate_template_base_for_class(base_specifier, base_spelling, under)
        auto_generate_base_class(base_specifier, base_spelling, under, recursive: false)
      end

      # Render a union plus any embedded unions/structs that need to appear first.
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
        result << self.render_cursor(cursor, "union", :under => under, :children => children,
                                     :cpp_type => @type_speller.qualified_class_name(cursor),
                                     :ruby_name => cursor.ruby_name)
        result.map { |s| s.chomp }.join("\n\n")
      end

      # Render a variable either as a Ruby constant or, for static class members,
      # as a singleton attribute on the owning Rice class.
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
            qualified_parent = @type_speller.qualified_display_name(cursor.semantic_parent)
            self.render_cursor(cursor, "variable",
                               :qualified_parent => qualified_parent)
          end
        end
      end

      # Render one constant definition for an enum value, macro, or variable.
      def visit_variable_constant(cursor)
        self.render_cursor(cursor, "constant",
                           :name => cursor.spelling.upcase_first,
                           :qualified_name => @type_speller.qualified_display_name(cursor))
      end

      # Render the optional project-level wrapper files that call every generated
      # per-header init function.
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

      # Return a callable address expression for free/static functions.
      # MSVC needs an explicit cast when the name refers to an overload set,
      # including when a concrete overload coexists with a function template.
      def callable_reference(cursor, qualified_name, signature)
        reference = "&#{qualified_name}"
        return reference unless requires_callable_cast?(cursor, signature)

        "static_cast<#{signature[1...-1]}>(#{reference})"
      end

      # Check whether a free/static callable shares its spelling with another
      # overload candidate in the same semantic parent.
      def requires_callable_cast?(cursor, signature)
        return false unless signature
        return false unless cursor.kind == :cursor_function || cursor.static?

        parent = cursor.semantic_parent
        return false unless parent

        overload_count = 0
        parent.each(false) do |sibling, _|
          next unless overload_candidate?(cursor, sibling)

          overload_count += 1
          return true if overload_count > 1
        end

        false
      end

      def overload_candidate?(cursor, sibling)
        return false unless sibling.spelling == cursor.spelling

        case cursor.kind
        when :cursor_function
          [:cursor_function, :cursor_function_template].include?(sibling.kind)
        when :cursor_cxx_method
          cursor.static? && [:cursor_cxx_method, :cursor_function_template].include?(sibling.kind)
        else
          false
        end
      end


      # Map a cursor kind such as `:cursor_class_decl` to the corresponding
      # visitor method symbol, for example `:visit_class_decl`.
      def figure_method(cursor)
        name = cursor.kind.to_s.delete_prefix("cursor_")
        "visit_#{name.underscore}".to_sym
      end

      # Add left padding to non-blank lines while preserving existing blank lines.
      def add_indentation(content, indentation)
        content.lines.map do |line|
          # Don't add indentation to blank lines
          line.strip.empty? ? line : " " * indentation + line
        end.join
      end

      # Render an ERB template with the current cursor injected into the locals.
      def render_cursor(cursor, template, local_variables = {})
        render_template(template, local_variables.merge(:cursor => cursor))
      end

      def template_cursor_definition(cursor)
        return nil unless cursor

        definition = cursor.definition
        return cursor if definition.kind == :cursor_invalid_file || definition.kind == :cursor_no_decl_found

        definition
      end

      def nested_template_builder_requires_outer_context?(cursor)
        parent = cursor.semantic_parent
        while parent
          break if [:cursor_invalid_file, :cursor_no_decl_found, :cursor_translation_unit].include?(parent.kind)
          return true if [:cursor_class_template,
                           :cursor_class_template_partial_specialization,
                           :cursor_function_template].include?(parent.kind)
          parent = parent.semantic_parent
        end

        false
      end

      # Returns [content, has_builders] where has_builders indicates if any builder templates were generated
      def render_class_templates(cursor, indentation: 0, strip: false)
        results = Array.new
        cursor.find_by_kind(true, :cursor_class_template) do |class_template_cursor|
          if class_template_cursor.private? || class_template_cursor.protected?
            next :continue
          end

          # Nested class templates inside class templates need the outer
          # template parameters and dependent parent qualification to form a
          # valid builder signature. Until that context is threaded through the
          # builder templates, skip emitting them rather than generating
          # invalid C++ such as Allocator::rebind<U>.
          if nested_template_builder_requires_outer_context?(class_template_cursor)
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
          unless translation_unit_file?(class_template_cursor)
            next :continue
          end

          # Skip if explicitly listed in symbols
          if skip_symbol?(class_template_cursor)
            next :continue
          end

          builder = visit_class_template_builder(class_template_cursor)
          results << builder if builder
        end
        content = merge_children({ nil => results }, indentation: indentation, strip: strip)
        has_builders = !results.empty? && !content.strip.empty?
        [content, has_builders]
      end

      # Visit eligible child cursors and bucket their rendered output by version
      # guard so later merging can emit `#if VERSION >= ...` blocks cleanly.
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

      # Merge previously rendered child content into final output text, with
      # optional method chaining, termination, indentation, and version guards.
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

      # Convenience wrapper around `visit_children` and `merge_children`.
      def render_children(cursor, indentation: 0, chain: false, terminate: false, strip: false,
                          exclude_kinds: Set.new, only_kinds: nil)
        versions = visit_children(cursor, exclude_kinds: exclude_kinds, only_kinds: only_kinds)
        merge_children(versions, indentation: indentation, chain: chain, terminate: terminate, strip: strip)
      end

    end
  end
end
