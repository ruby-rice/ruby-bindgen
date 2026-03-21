module FFI
  module Clang
    class Cursor
      def self.namer
        @namer || raise("Namer not set — generator must call Cursor.namer= before processing")
      end

      def self.namer=(value)
        @namer = value
      end

      def ruby_name
        self.class.namer.ruby(self)
      end

      def cruby_name
        self.class.namer.cruby(self)
      end

      def class_name_cpp
        first_child = self.first&.first
        case
          when first_child.nil?
            self.type.spelling
          when first_child.kind == :cursor_type_ref
            referee = first_child.referenced
            # Use word boundary to only replace complete type names, not partial matches
            # e.g., replace "any" but not "any" within "anyimpl"
            self.type.spelling.sub(/\b#{Regexp.escape(referee.spelling)}\b/, referee.qualified_name)
          else
            self.type.spelling
        end
      end

      def anonymous_definer
        return nil unless self.anonymous?

        if self.kind == :cursor_namespace
          return self
        end

        # This could be a typedef of a field declaration in union or struct
        #
        # typedef struct {
        #   union {
        #     char *sdata;
        #     int idata;
        #   } u;
        # } F_TextItemT;
        _, result = self.translation_unit.cursor.find do |child, parent|
          self.eql?(child) && (parent.kind == :cursor_field_decl ||
                               parent.kind == :cursor_typedef_decl)
        end

        # Or this could be a variable declaration
        #
        # struct {
        #   int Value;
        #   uint8_t String[4];
        # } MyArray_t;
        unless result
          variables = self.translation_unit.cursor.find_by_kind(true, :cursor_variable)
          result = variables.find do |variable|
            self.eql?(variable.type.declaration)
          end
        end
        result
      end

    end
  end
end
