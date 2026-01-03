module RubyBindgen
  class Namer
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
            cursor.spelling.gsub(/^operator /, "to_")
          when :cursor_function, :cursor_cxx_method
            # Ruby does not allow overriding (), so map it to #call
            if cursor.spelling == "operator()"
              "call"
            elsif cursor.spelling == "operator="
              "assign"
            elsif cursor.spelling.match(/^operator/)
              cursor.spelling.gsub(/^operator/, "")
            elsif cursor.type.result_type.spelling == "bool" &&
              "#{cursor.spelling.underscore.sub(/^is_/, "")}?"
            else
              cursor.spelling.underscore
            end
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
  end
end
