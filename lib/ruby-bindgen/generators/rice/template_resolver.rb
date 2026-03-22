module RubyBindgen
  module Generators
    # Resolves template specializations, omitted defaults, and inherited template
    # bases using libclang's semantic APIs plus source-written fallback text when
    # libclang does not expose a complete argument string.
    class TemplateResolver
      # Captures the semantic and source-written pieces for one template argument.
      # TemplateResolver builds these first, then later code renders them into
      # emitted C++ text.
      TemplateArgumentInfo = Struct.new(:kind, :type, :value, :unsigned_value, :source_text, keyword_init: true)

      def initialize(reference_qualifier:, type_speller:, namer:)
        @reference_qualifier = reference_qualifier
        @type_speller = type_speller
        @namer = namer
      end

      # Get full template arguments including default values.
      # When a typedef uses a template with default arguments, libclang reports
      # only the written arguments. Type arguments come from the semantic type
      # API, while non-type and template-template args fall back to source text
      # so expressions like `1 + 2` and names like `Box` are preserved.
      #
      # Examples:
      #   ExprValue<1 + 2>
      # stays
      #   ExprValue_instantiate<1 + 2>
      #
      #   Matrix<int, 2>
      # becomes
      #   Matrix_instantiate<int, 2, 1>
      def full_template_arguments(cursor, underlying_type, template_cursor)
        actual_args = specialization_template_arguments(cursor, underlying_type, template_cursor)

        return actual_args if template_cursor.nil?

        params = template_parameters(template_cursor)
        return actual_args if actual_args.length >= params.length

        argument_cursor = specialization_argument_cursor(underlying_type)
        missing_params = params.drop(actual_args.length)
        default_values = missing_params.each_with_index.map do |param, offset|
          template_param_default(param, argument_cursor: argument_cursor, argument_index: actual_args.length + offset)
        end.compact

        return actual_args if default_values.length != missing_params.length

        actual_args + default_values
      end

      # Build the C++ specialization spelling for a typedef/alias specialization
      # using the semantic template cursor plus the written template arguments.
      #
      # This is narrower than `full_template_arguments`: the Data_Type<T> side
      # should preserve the number of arguments written at the use site rather
      # than eagerly expanding omitted defaults. When libclang does not expose a
      # complete argument list for a non-type specialization, fall back to the
      # type speller's direct output.
      #
      # Examples:
      #   typedef FunctionTemplate<callback_ints> FunctionTemplateCallback;
      #   => Tests::FunctionTemplate<&Tests::callback_ints>
      #
      #   typedef MultiDefault<int> MultiDefaultInt;
      #   => MultiDefault<int>
      def specialization_spelling(specialization_cursor, specialized_type, template_cursor)
        return @type_speller.type_spelling(specialized_type) unless template_cursor

        actual_args = specialization_template_arguments(specialization_cursor, specialized_type, template_cursor)
        count = specialized_type.num_template_arguments
        return @type_speller.type_spelling(specialized_type) if count <= 0
        return @type_speller.type_spelling(specialized_type) unless actual_args.length == count

        "#{template_cursor.qualified_name}<#{actual_args.join(', ')}>"
      end

      def template_parameters(template_cursor)
        template_parameter_kinds = [:cursor_template_type_parameter,
                                    :cursor_non_type_template_parameter,
                                    :cursor_template_template_parameter]
        template_cursor.find_by_kind(false, *template_parameter_kinds).to_a
      end

      # Render a class template parameter for the instantiate helper's own
      # template declaration.
      #
      # Examples:
      #   `typename T`
      # stays
      #   `typename T`
      #
      #   `int N = 4`
      # becomes
      #   `int N`
      #
      #   `void (*Fn)(int, int)`
      # stays
      #   `void (*Fn)(int, int)`
      #
      #   `template<typename> class Container = Box`
      # becomes
      #   `template<typename> class Container`
      #
      #   `template<typename U = int> class Container = Box`
      # becomes
      #   `template<typename U = int> class Container`
      def template_parameter_signature(template_parameter)
        case template_parameter.kind
        when :cursor_template_type_parameter
          "typename #{template_parameter.spelling}"
        when :cursor_non_type_template_parameter
          declaration = template_parameter.extent.text
          return "int #{template_parameter.spelling}" if declaration.nil? || declaration.empty?

          separator_offset = @reference_qualifier.top_level_default_separator_offset(declaration)
          return declaration.rstrip unless separator_offset

          declaration.byteslice(0, separator_offset).rstrip
        when :cursor_template_template_parameter
          declaration = template_parameter.extent.text
          return "template<typename> class #{template_parameter.spelling}" if declaration.nil? || declaration.empty?

          separator_offset = @reference_qualifier.top_level_default_separator_offset(declaration)
          return declaration.rstrip unless separator_offset

          declaration.byteslice(0, separator_offset).rstrip
        else
          raise("Unsupported template parameter kind: #{template_parameter.kind}")
        end
      end

      # Split a comma-separated template argument list while keeping nested
      # templates, function pointer signatures, and string literals intact.
      #
      # Examples:
      #   'unsigned char, 2, 1'
      #   => ['unsigned char', '2', '1']
      #
      #   'void (*)(int, int)'
      #   => ['void (*)(int, int)']
      #
      #   'Support::Box<Support::Tag>, callback_t'
      #   => ['Support::Box<Support::Tag>', 'callback_t']
      def template_argument_texts(args_text)
        return [] if args_text.nil? || args_text.empty?

        result = []
        current = String.new
        angle_depth = 0
        paren_depth = 0
        bracket_depth = 0
        brace_depth = 0
        quote = nil
        escaped = false

        args_text.each_char do |char|
          current << char

          if quote
            if escaped
              escaped = false
            elsif char == '\\'
              escaped = true
            elsif char == quote
              quote = nil
            end
            next
          end

          case char
          when '"', "'"
            quote = char
          when '<'
            angle_depth += 1
          when '>'
            angle_depth -= 1 if angle_depth > 0
          when '('
            paren_depth += 1
          when ')'
            paren_depth -= 1 if paren_depth > 0
          when '['
            bracket_depth += 1
          when ']'
            bracket_depth -= 1 if bracket_depth > 0
          when '{'
            brace_depth += 1
          when '}'
            brace_depth -= 1 if brace_depth > 0
          when ','
            if angle_depth.zero? && paren_depth.zero? && bracket_depth.zero? && brace_depth.zero?
              current.chop!
              piece = current.strip
              result << piece unless piece.empty?
              current = String.new
            end
          end
        end

        piece = current.strip
        result << piece unless piece.empty?
        result
      end

      # Extract only the outer template argument list from a fully resolved
      # instantiation spelling.
      #
      # Examples:
      #   'Tests::Matx<unsigned char, 2, 1>'
      #   => 'unsigned char, 2, 1'
      #
      #   'Tests::CallbackBase<void (*)(int, int)>'
      #   => 'void (*)(int, int)'
      def template_argument_list_text(spelling)
        start_index = spelling.index('<')
        return nil unless start_index

        suffix, = balanced_template_suffix(spelling, start_index)
        return nil if suffix.empty?

        suffix[1..-2]
      end

      # Generate Ruby class name from a C++ template instantiation spelling
      # e.g., "Tests::Matx<unsigned char, 2, 1>" -> "MatxUnsignedChar21"
      def ruby_name_from_template(base_spelling, template_arguments)
        base_name = base_spelling.sub(/<.*>\z/, "").split("::").last.camelize
        argument_values = template_arguments.is_a?(Array) ? template_arguments : template_argument_texts(template_arguments)
        args_name = argument_values.map { |argument| ruby_name_from_template_argument(argument) }.join
        @namer.apply_rename_types(base_name + args_name)
      end

      # Given a typedef cursor and its underlying type, resolve the base class
      # to an actual instantiated type (e.g., PtrStep<unsigned char> instead of PtrStep<T>).
      # Correctly handles cases where derived and base templates have different numbers of
      # template parameters (e.g., Vec<_Tp, cn> : public Matx<_Tp, cn, 1>).
      # Returns the resolved base class spelling or nil if no base class exists.
      def resolve_base_instantiation(cursor, underlying_type)
        derived_template = specialized_template_cursor(underlying_type)
        if derived_template.nil?
          template_ref = cursor.find_first_by_kind(false, :cursor_template_ref)
          derived_template = template_ref&.referenced
        end
        return nil unless derived_template

        base_spec = derived_template.find_first_by_kind(false, :cursor_cxx_base_specifier)
        return nil unless base_spec

        base_template_ref = base_spec.find_first_by_kind(false, :cursor_template_ref)

        unless base_template_ref
          base_type_ref = base_spec.find_first_by_kind(false, :cursor_type_ref)
          return base_type_ref&.referenced&.qualified_name
        end

        template_params = template_parameters(derived_template).map(&:spelling)
        template_arg_values = full_template_arguments(cursor, underlying_type, derived_template)

        substitutions = {}
        template_params.each_with_index do |param, index|
          substitutions[param] = template_arg_values[index] if template_arg_values[index]
        end

        resolve_base_specifier_spelling(base_spec, substitutions: substitutions)
      end

      # Resolve a template base specifier by rewriting the written source with
      # semantic names and any current template-parameter substitutions.
      #
      # Examples:
      #   substitutions = { 'T' => 'unsigned char' }
      #   source        = 'BasePtr<T>'
      #   => 'Tests::BasePtr<unsigned char>'
      #
      #   substitutions = { 'Result' => 'void', 'Left' => 'int', 'Right' => 'int' }
      #   source        = 'CallbackBase<Result (*)(Left, Right)>'
      #   => 'Tests::CallbackBase<void (*)(int, int)>'
      def resolve_base_specifier_spelling(base_specifier, substitutions: {})
        base_template_ref = base_specifier.find_first_by_kind(false, :cursor_template_ref)

        unless base_template_ref
          base_type_ref = base_specifier.find_first_by_kind(false, :cursor_type_ref)
          return base_type_ref&.referenced&.qualified_name
        end

        source = base_specifier_source(base_specifier, base_template_ref)
        return nil unless source

        source_text, source_offset = source
        @reference_qualifier.qualify_source_references(base_specifier, source_text, source_offset, substitutions: substitutions)
      end

      private

      def specialized_template_cursor(type)
        [type, type.canonical].each do |check_type|
          declaration = check_type.declaration
          next if declaration.kind == :cursor_no_decl_found

          template = declaration.specialized_template
          return template unless template.kind == :cursor_invalid_file
        end

        nil
      end

      def specialization_template_arguments(specialization_cursor, specialized_type, template_cursor)
        specialization_template_argument_infos(specialization_cursor, specialized_type, template_cursor)
          .filter_map { |argument_info| specialization_template_argument_text(argument_info) }
      end

      def specialization_argument_cursor(specialized_type)
        declaration = specialized_type.declaration
        return nil if declaration.kind == :cursor_no_decl_found
        return declaration if declaration.num_template_arguments >= 0

        nil
      end

      def specialization_template_argument_infos(specialization_cursor, specialized_type, template_cursor)
        argument_cursor = specialization_argument_cursor(specialized_type)
        # The specialized declaration cursor includes omitted default arguments,
        # but the type API reports only the arguments written at the use site.
        count = specialized_type.num_template_arguments
        return [] if count <= 0

        source_fallbacks = specialization_template_argument_source_texts(specialization_cursor, template_cursor)

        count.times.filter_map do |index|
          specialization_template_argument_info(argument_cursor, specialized_type, index, source_fallbacks)
        end
      end

      def specialization_template_argument_info(argument_cursor, specialized_type, index, source_fallbacks)
        if argument_cursor
          kind = argument_cursor.template_argument_kind(index)
          case kind
          when :template_argument_type
            arg_type = argument_cursor.template_argument_type(index)
            return nil if arg_type.kind == :type_invalid

            return TemplateArgumentInfo.new(kind: kind, type: arg_type)
          when :template_argument_integral
            return TemplateArgumentInfo.new(kind: kind,
                                            value: argument_cursor.template_argument_value(index),
                                            unsigned_value: argument_cursor.template_argument_unsigned_value(index),
                                            source_text: source_fallbacks.shift)
          when :template_argument_null_ptr
            return TemplateArgumentInfo.new(kind: kind, source_text: source_fallbacks.shift)
          when :template_argument_template, :template_argument_template_expansion,
               :template_argument_expression, :template_argument_declaration,
               :template_argument_pack
            return TemplateArgumentInfo.new(kind: kind, source_text: source_fallbacks.shift)
          end
        end

        arg_type = specialized_type.template_argument_type(index)
        return nil if arg_type.kind == :type_invalid

        TemplateArgumentInfo.new(kind: :template_argument_type, type: arg_type)
      end

      def specialization_template_argument_text(argument_info)
        case argument_info.kind
        when :template_argument_type
          @type_speller.type_spelling(argument_info.type)
        when :template_argument_integral
          argument_info.source_text || argument_info.value.to_s
        when :template_argument_null_ptr
          argument_info.source_text || "nullptr"
        when :template_argument_template, :template_argument_template_expansion,
             :template_argument_expression, :template_argument_declaration,
             :template_argument_pack
          argument_info.source_text
        end
      end

      # Collect source-written template arguments that libclang does not expose
      # through the cursor template-argument APIs.
      #
      # Examples:
      #   typedef Vec<unsigned char, 2> Vec2b;
      #   => ['2']
      #
      #   typedef Holder<int, Support::Box> HolderInt;
      #   => ['Support::Box']
      #
      # We skip the outer template name itself and any child cursors that are
      # only details of a type argument, such as the `int` parameter cursors
      # inside `void (*)(int, int)`.
      def specialization_template_argument_source_texts(specialization_cursor, template_cursor)
        specialization_cursor.each(false).filter_map do |child|
          next if child.kind == :cursor_namespace_ref
          next if child.kind == :cursor_parm_decl
          next if child.kind == :cursor_type_ref
          next if child.kind == :cursor_template_ref && child.referenced == template_cursor

          source_text = child.extent.text
          source_offset = child.extent.start.offset

          if child.kind == :cursor_template_ref
            range = child.reference_name_range([:want_qualifier, :want_template_args, :want_single_piece])
            source_text = range&.text || source_text
            ref = child.referenced
            if ref && !ref.spelling.empty? && ref.spelling != ref.qualified_name
              source_text = @reference_qualifier.replacement_from_name_span(source_text, ref.spelling, ref.qualified_name) || source_text
            end
          else
            source_text = @reference_qualifier.qualify_source_references(child, source_text, source_offset)

            ref = child.referenced
            if ref &&
               [:cursor_function, :cursor_function_template, :cursor_cxx_method].include?(ref.kind) &&
               !source_text.lstrip.start_with?('&')
              source_text = "&#{source_text}"
            end
          end

          source_text
        rescue ArgumentError
          child.extent.text
        end
      end

      def template_param_default(param, argument_cursor: nil, argument_index: nil)
        case param.kind
        when :cursor_non_type_template_parameter
          qualify_template_non_type_default(param)
        when :cursor_template_type_parameter
          specialization_type_default(argument_cursor, argument_index) || qualify_template_type_default(param)
        when :cursor_template_template_parameter
          qualify_template_template_default(param)
        end
      end

      def specialization_type_default(argument_cursor, argument_index)
        return nil unless argument_cursor && argument_index
        return nil unless argument_cursor.template_argument_kind(argument_index) == :template_argument_type

        arg_type = argument_cursor.template_argument_type(argument_index)
        return nil if arg_type.kind == :type_invalid

        @type_speller.type_spelling(arg_type)
      end

      def qualify_template_type_default(param)
        extracted = @reference_qualifier.extract_default_text(param)
        return nil unless extracted

        default_text, default_text_offset = extracted
        @reference_qualifier.qualify_source_references(param, default_text, default_text_offset, qualify_decl_refs: false)
      end

      def qualify_template_non_type_default(param)
        extracted = @reference_qualifier.extract_default_text(param)
        return nil unless extracted

        default_text, default_text_offset = extracted
        @reference_qualifier.qualify_source_references(param, default_text, default_text_offset)
      end

      def qualify_template_template_default(param)
        extracted = @reference_qualifier.extract_default_text(param)
        return nil unless extracted

        default_text, default_text_offset = extracted
        @reference_qualifier.qualify_source_references(param, default_text, default_text_offset, qualify_decl_refs: false)
      end

      # Collapse one template argument spelling into a Ruby-safe class-name
      # fragment for auto-generated base classes.
      #
      # Examples:
      #   'unsigned char'
      #   => 'UnsignedChar'
      #
      #   'void (*)(int, int)'
      #   => 'VoidPtrIntInt'
      #
      #   'Support::Box<Support::Tag>'
      #   => 'BoxTag'
      def ruby_name_from_template_argument(argument)
        tokens = argument.scan(/::|&&|&|\*|[A-Za-z_]\w*|\d+/)

        tokens.each_with_index.filter_map do |token, index|
          next_token = tokens[index + 1]

          case token
          when '::'
            nil
          when '&&'
            'RvalueRef'
          when '&'
            'Ref'
          when '*'
            'Ptr'
          else
            next if next_token == '::'

            token.camelize
          end
        end.join
      end

      # Extract the written base instantiation starting at the template name so
      # access specifiers do not leak into the generated spelling.
      #
      # Examples:
      #   'public CallbackBase<Result (*)(Left, Right)>'
      #   => ['CallbackBase<Result (*)(Left, Right)>', offset of the C]
      #
      #   'public Support::ForeignBase<T>'
      #   => ['ForeignBase<T>', offset of the F]
      def base_specifier_source(base_specifier, base_template_ref)
        base_extent = base_specifier.extent
        source_text = base_extent.text
        source_offset = base_template_ref.extent.start.offset
        start_index = source_offset - base_extent.start.offset
        return nil if start_index.negative? || start_index >= source_text.bytesize

        [source_text.byteslice(start_index..), source_offset]
      rescue ArgumentError
        nil
      end

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
    end
  end
end
