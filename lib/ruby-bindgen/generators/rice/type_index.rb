module RubyBindgen
  module Generators
    # Builds shared lookups for typedef resolution and simple-name qualification.
    # Rice uses this index while walking the AST instead of threading raw hashes
    # through unrelated qualification and inheritance code paths.
    class TypeIndex
      def initialize
        clear
      end

      def clear
        @typedefs = {}
        @qualified_names = {}
      end

      def build!(cursor)
        clear

        cursor.find_by_kind(true, :cursor_typedef_decl, :cursor_type_alias_decl,
                            :cursor_class_template, :cursor_class_decl, :cursor_struct) do |child|
          record_type(child)
        end

        self
      end

      def typedef_for(canonical_spelling)
        @typedefs[canonical_spelling]
      end

      def qualified_name_for(simple_name)
        @qualified_names[simple_name]
      end

      def record_type(child)
        case child.kind
        when :cursor_typedef_decl, :cursor_type_alias_decl
          parent_kind = child.semantic_parent.kind
          return if parent_kind == :cursor_class_decl || parent_kind == :cursor_struct ||
                    parent_kind == :cursor_class_template || parent_kind == :cursor_class_template_partial_specialization

          canonical = child.underlying_type.canonical.spelling
          existing = @typedefs[canonical]
          if existing.nil? || prefer_replacement?(existing.qualified_name, child.qualified_name)
            @typedefs[canonical] = child
          end

          record_qualified_name(child.spelling, child.qualified_name)
        when :cursor_class_template, :cursor_class_decl, :cursor_struct
          return if child.spelling.empty?

          record_qualified_name(child.spelling, child.qualified_name, prefer_existing: true)
        end
      end

      def record_qualified_name(simple_name, qualified_name, prefer_existing: false)
        return if simple_name.nil? || simple_name.empty?
        return if simple_name == qualified_name

        existing = @qualified_names[simple_name]
        return if prefer_existing && existing

        if existing.nil? || prefer_replacement?(existing, qualified_name)
          @qualified_names[simple_name] = qualified_name
        end
      end

      private

      def prefer_replacement?(existing_qualified_name, new_qualified_name)
        existing_qualified_name.start_with?("std::") && !new_qualified_name.start_with?("std::")
      end
    end
  end
end
