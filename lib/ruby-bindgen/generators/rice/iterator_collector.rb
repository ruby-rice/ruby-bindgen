require 'set'

module RubyBindgen
  module Generators
    # Tracks iterator-related state across one translation-unit visit:
    #
    #   * Which Ruby iterator names a class exposes (each, each_const,
    #     each_reverse, each_reverse_const). Drives the each_const-only
    #     `alias each each_const` emission.
    #   * Which custom iterator types still need a generated
    #     `std::iterator_traits` specialization (for iterators that don't
    #     specialize std::iterator_traits themselves), de-duplicated
    #     across the multiple begin/rbegin callsites that hit the same
    #     iterator type.
    #
    # `record(cursor)` is the single entry point per iterator method.
    # `clear` resets between translation units.
    class IteratorCollector
      # Inferred traits for one custom iterator. The hash key under which
      # this is stored is the iterator's qualified name; we don't repeat
      # it here. Consumed directly by the ERB template.
      Inference = Data.define(:value_type, :is_const)

      # Returns the qualified-name → Inference map of iterators that need
      # a generated std::iterator_traits specialization.
      attr_reader :incomplete_iterators

      def initialize
        @incomplete_iterators = {}
        @iterator_names_by_class = Hash.new { |h, k| h[k] = Set.new }
      end

      def clear
        @incomplete_iterators.clear
        @iterator_names_by_class.clear
      end

      # Record an iterator method on its parent class. Returns the Ruby
      # iterator name to render (e.g. "each", "each_const") or nil for
      # variants we deliberately skip:
      #
      #   * cbegin/crbegin — would emit a duplicate each_const /
      #     each_reverse_const since C++ allows them on non-const
      #     receivers but Ruby has no const distinction.
      #   * end/cend/rend/crend — handled implicitly by Rice's
      #     define_iterator.
      def record(cursor)
        ruby_name = ruby_iterator_name(cursor)
        return nil unless ruby_name

        @iterator_names_by_class[cursor.semantic_parent.cruby_name] << ruby_name
        record_traits_if_needed(cursor.result_type)
        ruby_name
      end

      # True when `cruby_name` exposes only const iteration. The caller
      # emits an `alias each each_const` so Ruby code can iterate without
      # spelling the const variant.
      def each_const_only?(cruby_name)
        names = @iterator_names_by_class[cruby_name]
        names.include?("each_const") && !names.include?("each")
      end

      private

      def ruby_iterator_name(cursor)
        case cursor.spelling
        when "begin"  then cursor.const? ? "each_const"         : "each"
        when "rbegin" then cursor.const? ? "each_reverse_const" : "each_reverse"
        end
      end

      def record_traits_if_needed(iterator_type)
        inference = infer_traits(iterator_type)
        return unless inference

        # Key by qualified iterator name so the same iterator hit via
        # different begin/rbegin callsites gets one specialization.
        @incomplete_iterators[iterator_type.declaration.qualified_name] = inference
      end

      # Returns an Inference if `iterator_type` needs a generated
      # std::iterator_traits specialization, or nil if it doesn't.
      # Inputs that already declare the full trait set, that live in
      # `std::`, or whose value type can't be recovered are left alone.
      def infer_traits(iterator_type)
        decl = iterator_type.declaration
        return nil if decl.kind == :cursor_no_decl_found
        return nil if decl.qualified_name&.start_with?('std::')

        # If the type is reached through a typedef (e.g.
        # `typedef SparseMatConstIterator_<uchar> SparseMatConstIterator`)
        # walk to the underlying class so trait/operator lookup hits
        # the actual class members rather than the typedef cursor.
        if decl.kind == :cursor_typedef_decl || decl.kind == :cursor_type_alias_decl
          underlying = iterator_type.canonical.declaration
          decl = underlying if underlying.kind != :cursor_no_decl_found
        end

        return nil if traits_already_complete?(decl)

        value_type = infer_value_type(decl)
        return nil unless value_type

        Inference.new(
          value_type: value_type_qualified_name(value_type),
          is_const: value_type.const_qualified?
        )
      end

      REQUIRED_TRAITS = %w[
        value_type
        reference
        pointer
        difference_type
        iterator_category
      ].freeze
      private_constant :REQUIRED_TRAITS

      def traits_already_complete?(decl)
        present = Set.new
        decl.each(false) do |child, _|
          next unless child.kind == :cursor_type_alias_decl ||
                      child.kind == :cursor_typedef_decl
          present << child.spelling if REQUIRED_TRAITS.include?(child.spelling)
        end
        present.size == REQUIRED_TRAITS.size
      end

      # Recursive iteration so inherited operator* on a base class is
      # found. Iterators without operator* (e.g. OpenCV's
      # SparseMatConstIterator which exposes node()) cannot have traits
      # inferred and must be skipped via the symbols config.
      def infer_value_type(decl)
        decl.each do |child, _|
          next unless child.kind == :cursor_cxx_method &&
                      child.spelling == "operator*"
          # non_reference_type is a no-op on non-references, so this
          # handles `T`, `T &`, and `const T &` uniformly.
          return child.result_type.non_reference_type
        end
        nil
      end

      # Prefer the value type's qualified name from its declaration;
      # fall back to the unqualified spelling for primitives (no decl).
      def value_type_qualified_name(value_type)
        decl = value_type.declaration
        if decl && decl.kind != :cursor_no_decl_found
          decl.qualified_name
        else
          value_type.unqualified_type.spelling
        end
      end
    end
  end
end
