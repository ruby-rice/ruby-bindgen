module RubyBindgen
  module Generators
    # Builds shared lookups for typedef resolution and simple-name qualification.
    # Rice uses this index while walking the AST instead of threading raw hashes
    # through unrelated qualification and inheritance code paths.
    class TypeIndex
      def initialize
        clear
      end

      # Reset both lookup tables before a fresh AST walk.
      #
      # `@typedefs` maps canonical type spellings to the typedef/alias cursor
      # that should win for that canonical type, for example:
      #   "int" => cursor for `using MyInt = int`
      #
      # `@qualified_names` maps a simple name to the preferred qualified name:
      #   "Box" => "Example::Box"
      def clear
        @typedefs = {}
        @qualified_names = {}
      end

      # Walk the translation unit once and collect the shared type lookups used
      # by the Rice generator.
      #
      # Only top-level typedefs/aliases are indexed. Member aliases are skipped
      # because they are only valid through the owning class scope and cannot be
      # reused as generic replacements elsewhere in generated code.
      def build!(cursor)
        clear

        cursor.find_by_kind(true, :cursor_typedef_decl, :cursor_type_alias_decl,
                            :cursor_class_template, :cursor_class_decl, :cursor_struct) do |child|
          record_type(child)
        end

        self
      end

      # Find the preferred typedef/alias cursor for a canonical type spelling.
      #
      # Example:
      #   typedef_for("int")
      # returns the cursor for `using MyInt = int`
      def typedef_for(canonical_spelling)
        @typedefs[canonical_spelling]
      end

      # Find the preferred qualified name for a simple type name.
      #
      # Example:
      #   qualified_name_for("Box")
      # returns "Example::Box"
      def qualified_name_for(simple_name)
        @qualified_names[simple_name]
      end

      # Record one discovered cursor into the appropriate lookup table.
      #
      # Typedefs and aliases populate both:
      # - canonical type -> preferred typedef cursor
      # - simple name -> preferred qualified spelling
      #
      # Class/template declarations only populate the simple-name lookup because
      # they do not stand in for another canonical type.
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

      # Store the preferred qualified spelling for a simple name.
      #
      # `prefer_existing: true` is used for class declarations so an earlier
      # alias like `Example::Box` is not overwritten later by the class/template
      # declaration for the same simple name.
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

      # Prefer user/library names over `std::...` when both map to the same
      # simple name. This keeps project-local aliases such as `cv::String`
      # instead of replacing them with `std::string`.
      def prefer_replacement?(existing_qualified_name, new_qualified_name)
        existing_qualified_name.start_with?("std::") && !new_qualified_name.start_with?("std::")
      end
    end
  end
end
