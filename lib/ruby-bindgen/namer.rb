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

      # Increment/decrement - arity-dependent (prefix=0 args, postfix=1 arg)
      '++' => ->(cursor) { cursor.type.args_size == 0 ? 'increment_pre' : 'increment' },
      '--' => ->(cursor) { cursor.type.args_size == 0 ? 'decrement_pre' : 'decrement' },

      # Dereference vs multiply - arity-dependent (unary=0 args, binary=1 arg)
      '*' => ->(cursor) { cursor.type.args_size == 0 ? 'dereference' : '*' },

      # Pass-through operators - Ruby supports these directly
      '+' => '+',
      '-' => '-',
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
      'int' => 'i',
      'long' => 'i',
      'long long' => 'i',
      'short' => 'i',
      'unsigned int' => 'i',
      'unsigned long' => 'i',
      'unsigned long long' => 'i',
      'unsigned short' => 'i',
      'float' => 'f',
      'double' => 'f',
      'long double' => 'f',
      'bool' => 'bool',
      'std::string' => 's',
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
      # Extract the type from "operator TYPE"
      type_name = cursor.spelling.sub(/^operator\s*/, '')

      # Look up Ruby convention for this type
      suffix = CONVERSION_TYPE_MAPPINGS[type_name]
      if suffix
        "to_#{suffix}"
      else
        # Fallback: underscore the type name
        "to_#{type_name.underscore}"
      end
    end

    # Handle operators and regular methods
    def ruby_operator_or_method(cursor)
      spelling = cursor.spelling

      # Regular method (not an operator)
      unless spelling.start_with?('operator')
        if cursor.type.result_type.spelling == "bool"
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
