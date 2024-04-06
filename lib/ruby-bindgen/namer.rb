module RubyBindgen
  class Namer
    def initialize(strip_prefixes = [], strip_suffixes = [])
      @strip_prefixes = strip_prefixes
      @strip_suffixes = strip_suffixes
    end

    def ruby(cursor)
      if cursor.anonymous?
        cursor.anonymous_definer.spelling.camelize
      else
        case cursor.kind
          when :cursor_translation_unit
            basename = File.basename(cursor.spelling, File.extname(cursor.spelling))
            basename.camelize
          when :cursor_conversion_function
            cursor.spelling.gsub(/^operator /, "to_")
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
          when :cursor_translation_unit
            cursor.spelling.camelize
          when :cursor_typedef_decl
            cursor.spelling
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
          "rb_c#{cursor.type.spelling.camelize}"
        when :cursor_struct
          "rb_c#{cursor.type.spelling.camelize}"
        when :cursor_enum_decl
          "rb_c#{cursor.type.spelling.camelize}"
        when :cursor_namespace
          "rb_m#{cursor.qualified_name.camelize}"
        when :cursor_typedef_decl
          "rb_c#{cursor.spelling.camelize}"
        else
          cursor.spelling.underscore
      end
    end
  end
end
