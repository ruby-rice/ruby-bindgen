module FFI
  module Clang
    class Cursor
      def self.namer
        @namer || RubyBindgen::Namer.new
      end

      def self.namer=(value)
        @namer = values
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

      # Find first child cursor matching any of the given kinds.
      # Short-circuits on first match to avoid building full array.
      def find_first_by_kind(recurse, *kinds)
        self.each(recurse) do |child, parent|
          return child if kinds.include?(child.kind)
        end
        nil
      end

      def overloads
        # Include function templates - if a regular function has a template overload,
        # we need explicit type cast (e.g., KernelArg::Constant has both const Mat& and template versions)
        #
        # Also check base classes - if a method is overloaded in the base class hierarchy,
        # we need explicit signatures even when only one variant is declared in this class.
        # This handles the cv::xfeatures2d::AffineFeature2D::detect case where detect is
        # overloaded in cv::Feature2D but AffineFeature2D only overrides one variant.
        #
        # Important: Only consider it an overload if the method signatures differ.
        # Overrides (same signature in derived class) don't need explicit type casts.
        methods = []
        self.find_by_kind(false, :cursor_cxx_method, :cursor_function, :cursor_function_template) do |m|
          methods << m
        end

        # Collect methods from base classes
        self.find_by_kind(false, :cursor_cxx_base_specifier) do |base|
          base_decl = base.type.declaration
          next if base_decl.kind == :cursor_no_decl_found

          # Get methods from base class (recursively handled by base's overloads call)
          base_decl.find_by_kind(false, :cursor_cxx_method, :cursor_function, :cursor_function_template) do |m|
            methods << m
          end

          # Also recursively check base class's base classes
          base_decl.overloads.each do |name, cursors|
            methods.concat(cursors)
          end
        end

        # Group by name, then check if there are actually different signatures
        result = methods.group_by do |cursor|
          cursor.spelling
        end.select do |spelling, cursors|
          # Need at least 2 methods with the same name
          next false if cursors.size < 2

          # Check if there are different signatures (not just overrides)
          # Use the type's spelling which includes parameter types
          signatures = cursors.map { |c| c.type.spelling }.uniq
          signatures.size > 1
        end
        result
      end
    end
  end
end
