module RubyBindgen
  class Namer
    def initialize(rename_types = NameMapper.new, rename_methods = NameMapper.new,
                   conversion_mappings = NameMapper.new)
      @rename_types = rename_types
      @rename_methods = rename_methods
      @conversion_mappings = conversion_mappings
    end

    def ruby(cursor)
      if cursor.anonymous? && cursor.kind == :cursor_namespace
        "Anonymous"
      elsif cursor.anonymous?
        definer = cursor.anonymous_definer
        definer ? definer.spelling.camelize : nil
      else
        case cursor.kind
          when :cursor_translation_unit
            basename = File.basename(cursor.spelling, File.extname(cursor.spelling))
            basename.camelize
          when :cursor_conversion_function
            ruby_conversion_function(cursor)
          when :cursor_function, :cursor_cxx_method
            ruby_operator_or_method(cursor)
          when :cursor_struct, :cursor_union, :cursor_enum_decl, :cursor_class_decl, :cursor_namespace
            @rename_types.lookup(cursor.spelling) || cursor.spelling.camelize
          when :cursor_field_decl
            cursor.spelling.underscore
          when :cursor_typedef_decl
            cursor.underlying_type.declaration.invalid? ?
              cursor.spelling.underscore :
              ruby(cursor.underlying_type.declaration)
          when :cursor_variable
            cursor.spelling.camelize
          else
            cursor.spelling.underscore
        end
      end
    end

    def cruby(cursor)
      case cursor.kind
        when :cursor_class_decl
          "rb_c#{cursor.type.spelling.sub("(anonymous namespace)", "Anonymous").camelize}"
        when :cursor_struct
          "rb_c#{cursor.type.spelling.camelize}"
        when :cursor_enum_decl
          "rb_c#{cursor.type.spelling.sub("(anonymous namespace)", "Anonymous").camelize}"
        when :cursor_namespace
          if cursor.anonymous?
            # qualified_name is nil for translation units
            "rb_m#{cursor.semantic_parent.qualified_name&.camelize}Anonymous"
          else
            "rb_m#{cursor.qualified_name.camelize}"
          end
        when :cursor_typedef_decl
          "rb_c#{cursor.spelling.sub("(anonymous namespace)", "Anonymous").camelize}"
        when :cursor_translation_unit
          "Class(rb_cObject)"
        else
          cursor.spelling.underscore
      end
    end

    # Apply rename_types to a generated Ruby class name.
    # Accepts one or more candidate names to try (e.g., raw C++ name, camelized name).
    # Returns the first match, or the last candidate as fallback.
    def apply_rename_types(*names)
      @rename_types.lookup(*names) || names.last
    end

    private

    # Handle conversion functions like operator int(), operator float()
    def ruby_conversion_function(cursor)
      # Use result_type.spelling to get the original typedef name (e.g., "size_t")
      # rather than the resolved type from cursor.spelling (e.g., "unsigned long")
      type_name = cursor.type.result_type.spelling

      # Look up Ruby convention for this type
      suffix = @conversion_mappings.lookup(type_name)
      if suffix
        "to_#{suffix}"
      else
        # Handle std::basic_string variants (std::string is a typedef)
        if type_name.include?('basic_string')
          return "to_s"
        end

        # Clean up the type name for Ruby method naming:
        # - Remove reference/pointer markers
        # - Use only the final type name (after last ::)
        # - Convert to underscore style
        clean_name = type_name.gsub(/[&*]/, '').strip
        clean_name = clean_name.split('::').last || clean_name
        # Remove template parameters for cleaner method names
        clean_name = clean_name.sub(/<.*>$/, '')
        "to_#{clean_name.underscore}"
      end
    end

    # Handle operators and regular methods
    def ruby_operator_or_method(cursor)
      # Check rename_methods first (includes operator mappings merged by generator)
      result = @rename_methods.lookup(*qualified_name_candidates(cursor), cursor.spelling)

      case result
      when String then return result
      when Proc then return result.call(cursor)
      end

      # No mapping — apply heuristics for non-operators only
      spelling = cursor.spelling
      unless spelling.start_with?('operator')
        is_bool = cursor.type.result_type.spelling == "bool"
        # Methods starting with "is" prefix (isFoo or is_foo) are predicates
        is_prefixed = spelling.match?(/^is[A-Z_]/)

        # Add ? suffix for predicate methods:
        # 1. bool return with no parameters, OR
        # 2. bool return with "is" prefix (regardless of parameters)
        if is_bool && (cursor.type.args_size == 0 || is_prefixed)
          return "#{spelling.underscore.sub(/^is_/, "")}?"
        else
          return spelling.underscore
        end
      end

      # Unknown operator with no mapping
      raise "Unknown operator: #{spelling}"
    end

    def qualified_name_candidates(cursor)
      candidates = []

      qualified_name = cursor.qualified_name
      candidates << qualified_name if qualified_name && !qualified_name.empty?

      parent = cursor.semantic_parent
      if parent && [:cursor_class_decl, :cursor_struct, :cursor_class_template].include?(parent.kind)
        # parent.type.spelling collapses inline namespaces, so rename_methods can
        # match either `cv::dnn::dnn4_v20241223::Layer::init` or `cv::dnn::Layer::init`.
        type_qualified = "#{parent.type.spelling}::#{cursor.spelling}"
        candidates << type_qualified unless candidates.include?(type_qualified)
      end

      candidates
    end
  end
end
