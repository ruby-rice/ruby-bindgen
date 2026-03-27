module RubyBindgen
  module Generators
    # Builds callable signatures and argument metadata for generated Rice
    # bindings, including default-value handling and buffer detection.
    class SignatureBuilder
      STRING_POINTER_TYPES = [
        :type_char_u,
        :type_char_s,
        :type_wchar
      ].freeze

      def initialize(type_speller:, reference_qualifier:, copyable_type:, cursor_literals:, fundamental_types:)
        @type_speller = type_speller
        @reference_qualifier = reference_qualifier
        @copyable_type = copyable_type
        @cursor_literals = cursor_literals
        @fundamental_types = fundamental_types
      end

      # Check if a type should use ArgBuffer (for parameters) or ReturnBuffer (for return types).
      # Returns true if the type is:
      #   - A pointer to a fundamental type (int*, double*, char*, etc.)
      #   - A double pointer (T**) - pointer to any pointer type
      # Types that look like pointers to fundamentals but are actually strings
      # char* and wchar_t* are C strings, not buffers
      def buffer_type?(type)
        return false unless type.kind == :type_pointer

        pointee = type.pointee
        pointee_kind = pointee.canonical.kind

        return false if STRING_POINTER_TYPES.include?(pointee_kind)
        return true if @fundamental_types.include?(pointee_kind)
        return true if pointee_kind == :type_pointer

        false
      end

      def constructor_signature(cursor)
        signature = Array.new

        case cursor.kind
        when :cursor_constructor
          parent = cursor.semantic_parent
          class_name = @type_speller.qualified_display_name(parent)
          signature << class_name
          params = @type_speller.type_spellings(cursor)
          if cursor.semantic_parent&.kind == :cursor_class_template
            params = params.map { |pt| @type_speller.qualify_class_template_typedefs(pt, cursor.semantic_parent) }
          end
          if parent
            params = params.map { |pt| @type_speller.qualify_class_static_members(pt, parent) }
          end
          if parent&.kind == :cursor_class_template
            params = params.map { |pt| @type_speller.preserve_template_parameter_names(pt, parent) }
          end
          signature += params

        when :cursor_class_decl, :cursor_struct
          signature << @type_speller.qualified_display_name(cursor)
        else
          raise("Unsupported cursor kind: #{cursor.kind}")
        end

        result = signature.compact.join(", ")
        result.match(/std::initializer_list/) ? nil : result
      end

      def arguments(cursor)
        (0...cursor.num_arguments).map do |index|
          param = cursor.argument(index)
          param_name = param.spelling.empty? ? "arg_#{index}" : param.spelling.underscore

          type = param.type
          if type.kind == :type_pointer && type.pointee.kind == :type_unexposed
            type_param = type.pointee.spelling
            arg_class = "std::conditional_t<std::is_fundamental_v<#{type_param}>, ArgBuffer, Arg>"
          else
            arg_class = buffer_type?(type) ? "ArgBuffer" : "Arg"
          end
          result = "#{arg_class}(\"#{param_name}\")"

          default_value = find_default_value(param)
          if default_value && @copyable_type.call(param.type)
            qualified_type = @type_speller.type_spelling(param.type)
            if param.semantic_parent&.semantic_parent&.kind == :cursor_class_template
              qualified_type = @type_speller.qualify_class_template_typedefs(qualified_type, param.semantic_parent.semantic_parent)
            end

            decl = param.type.declaration
            is_array_alias = (decl.kind == :cursor_type_alias_decl || decl.kind == :cursor_typedef_decl) &&
                             [:type_constant_array, :type_incomplete_array].include?(decl.underlying_type.canonical.kind)
            if is_array_alias
              result << " = #{default_value}"
            elsif default_value == '{}'
              base_type = qualified_type.sub(/\bconst\s+/, '').sub(/\s*&\s*$/, '')
              result << " = static_cast<#{qualified_type}>(#{base_type}{})"
            else
              result << " = static_cast<#{qualified_type}>(#{default_value})"
            end
          end
          result
        end
      end

      def method_signature(cursor)
        param_types = @type_speller.type_spellings(cursor)
        result_type = @type_speller.type_spelling(cursor.type.result_type)

        if cursor.semantic_parent&.kind == :cursor_class_template
          result_type = @type_speller.qualify_class_template_typedefs(result_type, cursor.semantic_parent)
          param_types = param_types.map { |pt| @type_speller.qualify_class_template_typedefs(pt, cursor.semantic_parent) }
        end

        parent = cursor.semantic_parent
        if parent
          result_type = @type_speller.qualify_class_static_members(result_type, parent)
          param_types = param_types.map { |pt| @type_speller.qualify_class_static_members(pt, parent) }
          if same_self_type?(cursor.type.result_type, parent)
            result_type = self_type_spelling(cursor.type.result_type, @type_speller.qualified_display_name(parent))
          end
        end
        if parent&.kind == :cursor_class_template
          result_type = @type_speller.preserve_template_parameter_names(result_type, parent)
          param_types = param_types.map { |pt| @type_speller.preserve_template_parameter_names(pt, parent) }
        end

        signature = Array.new
        if cursor.kind == :cursor_function || cursor.static?
          signature << "#{result_type}(*)(#{param_types.join(', ')})"
        else
          signature << "#{result_type}(#{@type_speller.qualified_display_name(cursor.semantic_parent)}::*)(#{param_types.join(', ')})"
        end

        signature << "const" if cursor.const?
        signature << "noexcept" if cursor.type.exception_specification == :basic_noexcept

        result = "<#{signature.join(' ')}>"
        result.match(/std::initializer_list/) ? nil : result
      end

      private

      def same_self_type?(type, parent)
        check_type = type
        check_type = check_type.non_reference_type if [:type_lvalue_ref, :type_rvalue_ref].include?(check_type.kind)
        normalize_spelling(check_type.spelling) == normalize_spelling(parent.display_name)
      end

      def self_type_spelling(type, qualified_parent)
        check_type = type
        suffix = ""
        if check_type.kind == :type_lvalue_ref
          suffix = " &"
          check_type = check_type.non_reference_type
        elsif check_type.kind == :type_rvalue_ref
          suffix = " &&"
          check_type = check_type.non_reference_type
        end

        prefix = check_type.const_qualified? ? "const " : ""
        "#{prefix}#{qualified_parent}#{suffix}"
      end

      def normalize_spelling(spelling)
        spelling.to_s.gsub(/\s+/, ' ').strip
      end

      # Finds the default value expression for a parameter and returns it with qualified names.
      #
      # Architecture: Separates text extraction from semantic analysis to avoid macro expansion issues.
      # - Text extraction: Uses param.extent.text (original source) to get the default value
      # - Semantic analysis: Uses cursor traversal only to identify what needs qualification
      #
      # This approach is necessary because cursor extent text can reflect macro expansion on some platforms.
      # For example, on Windows UCRT, 'stdout' expands to '__acrt_iob_func', but we want to preserve 'stdout'.
      def find_default_value(param)
        extracted = @reference_qualifier.extract_default_text(param)
        return nil unless extracted
        default_text, default_text_offset = extracted

        default_value_kinds = [:cursor_unexposed_expr, :cursor_call_expr, :cursor_decl_ref_expr,
                               :cursor_c_style_cast_expr, :cursor_cxx_static_cast_expr,
                               :cursor_cxx_functional_cast_expr, :cursor_cxx_typeid_expr,
                               :cursor_paren_expr] + @cursor_literals
        default_expr = param.find_by_kind(false, *default_value_kinds).find do |expr|
          if expr.kind == :cursor_decl_ref_expr
            ref = expr.referenced
            ref && ref.kind != :cursor_non_type_template_parameter && ref.kind != :cursor_template_type_parameter
          else
            true
          end
        end
        return nil unless default_expr

        @reference_qualifier.qualify_source_references(default_expr, default_text, default_text_offset)
      end
    end
  end
end
