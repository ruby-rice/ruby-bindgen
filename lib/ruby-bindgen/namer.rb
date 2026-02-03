module RubyBindgen
  class Namer
    # Mapping of C++ operators to Ruby method names per Rice documentation
    # Values can be:
    #   - String: direct mapping
    #   - Proc: called with cursor to determine mapping (for arity-dependent operators)
    OPERATOR_MAPPINGS = {
      # Assignment operators - not overridable in Ruby
      '=' => 'assign',
      '+=' => 'assign_plus',
      '-=' => 'assign_minus',
      '*=' => 'assign_multiply',
      '/=' => 'assign_divide',
      '%=' => 'assign_modulus',

      # Bitwise assignment operators - not overridable in Ruby
      '&=' => 'assign_and',
      '|=' => 'assign_or',
      '^=' => 'assign_xor',
      '<<=' => 'assign_left_shift',
      '>>=' => 'assign_right_shift',

      # Logical operators - && and || not overridable in Ruby
      '&&' => 'logical_and',
      '||' => 'logical_or',

      # Function call operator
      '()' => 'call',

      # Member access through pointer (arrow operator)
      '->' => 'arrow',

      # Increment/decrement - arity-dependent (prefix=0 args, postfix=1 arg)
      '++' => ->(cursor) { cursor.type.args_size == 0 ? 'increment' : 'increment_post' },
      '--' => ->(cursor) { cursor.type.args_size == 0 ? 'decrement' : 'decrement_post' },

      # Dereference vs multiply - arity-dependent (unary=0 args, binary=1 arg)
      '*' => ->(cursor) { cursor.type.args_size == 0 ? 'dereference' : '*' },

      # Unary plus/minus vs binary - arity-dependent
      # Ruby uses +@ and -@ for unary operators, + and - for binary
      # Member: unary=0 args, binary=1 arg
      # Non-member: unary=1 arg, binary=2 args (but we check member arity here)
      '+' => ->(cursor) { cursor.type.args_size == 0 ? '+@' : '+' },
      '-' => ->(cursor) { cursor.type.args_size == 0 ? '-@' : '-' },

      # Pass-through operators - Ruby supports these directly
      '/' => '/',
      '%' => '%',
      '&' => '&',
      '|' => '|',
      '^' => '^',
      '~' => '~',
      '<<' => '<<',
      '>>' => '>>',
      '==' => '==',
      '!=' => '!=',
      '<' => '<',
      '>' => '>',
      '<=' => '<=',
      '>=' => '>=',
      '!' => '!',
      '[]' => '[]',
    }.freeze

    # Mapping of C++ type names to Ruby conversion method suffixes
    CONVERSION_TYPE_MAPPINGS = {
      # Standard integer types
      'int' => 'i',
      'long' => 'l',
      'long long' => 'i64',
      'short' => 'i16',
      'unsigned int' => 'u',
      'unsigned long' => 'ul',
      'unsigned long long' => 'u64',
      'unsigned short' => 'u16',
      # Fixed-width integer types
      'int8_t' => 'i8',
      'int16_t' => 'i16',
      'int32_t' => 'i32',
      'int64_t' => 'i64',
      'uint8_t' => 'u8',
      'uint16_t' => 'u16',
      'uint32_t' => 'u32',
      'uint64_t' => 'u64',
      # Size type (platform-independent)
      'size_t' => 'size',
      # Floating point types
      'float' => 'f32',
      'double' => 'f',
      'long double' => 'ld',
      # Other types
      'bool' => 'bool',
      'std::string' => 's',
      'std::__cxx11::basic_string<char>' => 's',
      'std::basic_string<char>' => 's',
      'basic_string<char>' => 's',
      'char *' => 's',
      'const char *' => 's',
    }.freeze

    def initialize(strip_prefixes = [], strip_suffixes = [])
      @strip_prefixes = strip_prefixes
      @strip_suffixes = strip_suffixes
    end

    def ruby(cursor)
      if cursor.anonymous? && cursor.kind == :cursor_namespace
        "Anonymous"
      elsif cursor.anonymous?
        cursor.anonymous_definer.spelling.camelize
      else
        case cursor.kind
          when :cursor_translation_unit
            basename = File.basename(cursor.spelling, File.extname(cursor.spelling))
            basename.camelize
          when :cursor_conversion_function
            ruby_conversion_function(cursor)
          when :cursor_function, :cursor_cxx_method
            ruby_operator_or_method(cursor)
          when :cursor_enum_decl
            cursor.spelling.camelize
          when :cursor_field_decl
            cursor.spelling.underscore
          when :cursor_typedef_decl
            cursor.underlying_type.declaration.invalid? ?
              cursor.spelling.underscore :
              ruby(cursor.underlying_type.declaration)
          when :cursor_struct
            cursor.spelling.camelize
          when :cursor_union
            cursor.spelling.camelize
          when :cursor_variable
            cursor.spelling.camelize
          when :cursor_class_decl
            cursor.spelling.camelize
          when :cursor_namespace
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

    private

    # Handle conversion functions like operator int(), operator float()
    def ruby_conversion_function(cursor)
      # Use result_type.spelling to get the original typedef name (e.g., "size_t")
      # rather than the resolved type from cursor.spelling (e.g., "unsigned long")
      type_name = cursor.type.result_type.spelling

      # Look up Ruby convention for this type
      suffix = CONVERSION_TYPE_MAPPINGS[type_name]
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
      spelling = cursor.spelling

      # Regular method (not an operator)
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

      # Extract the operator symbol
      op = spelling.sub(/^operator\s*/, '')

      # Look up in operator mappings
      mapping = OPERATOR_MAPPINGS[op]
      case mapping
      when String
        mapping
      when Proc
        mapping.call(cursor)
      else
        raise "Unknown operator: #{op}"
      end
    end
  end
end
