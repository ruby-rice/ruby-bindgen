require 'set'

module RubyBindgen
  module Generators
    # Infers `std::iterator_traits` members for custom iterator types that
    # don't specialize `std::iterator_traits` themselves. Rice needs the
    # specialization in the generated bindings so STL algorithms (and
    # consumers that go through `std::iterator_traits`) can use the
    # iterator. Inputs that already declare the full set of traits, or
    # that live in `std::`, or whose value type can't be recovered, are
    # left alone — the caller emits no specialization for them.
    module IteratorTraits
      # Inferred traits for one iterator. The hash key under which the
      # caller stores this is the iterator's qualified name; we don't
      # repeat it here.
      Inference = Data.define(:value_type, :is_const)

      # Returns an Inference if `iterator_type` needs a generated
      # `std::iterator_traits` specialization, or nil if it doesn't.
      def self.infer(iterator_type)
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

      def self.traits_already_complete?(decl)
        present = Set.new
        decl.each(false) do |child, _|
          next unless child.kind == :cursor_type_alias_decl ||
                      child.kind == :cursor_typedef_decl
          present << child.spelling if REQUIRED_TRAITS.include?(child.spelling)
        end
        present.size == REQUIRED_TRAITS.size
      end
      private_class_method :traits_already_complete?

      # Recursive iteration so inherited operator* on a base class is
      # found. Iterators without operator* (e.g. OpenCV's
      # SparseMatConstIterator which exposes node()) cannot have traits
      # inferred and must be skipped via the symbols config.
      def self.infer_value_type(decl)
        decl.each do |child, _|
          next unless child.kind == :cursor_cxx_method &&
                      child.spelling == "operator*"
          # non_reference_type is a no-op on non-references, so this
          # handles `T`, `T &`, and `const T &` uniformly.
          return child.result_type.non_reference_type
        end
        nil
      end
      private_class_method :infer_value_type

      # Prefer the value type's qualified name from its declaration;
      # fall back to the unqualified spelling for primitives (no decl).
      def self.value_type_qualified_name(value_type)
        decl = value_type.declaration
        if decl && decl.kind != :cursor_no_decl_found
          decl.qualified_name
        else
          value_type.unqualified_type.spelling
        end
      end
      private_class_method :value_type_qualified_name
    end
  end
end
