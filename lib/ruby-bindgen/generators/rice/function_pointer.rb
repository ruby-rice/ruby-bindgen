module RubyBindgen
  module Generators
    # Build the C++ pointer-to-function expression Rice needs to bind a
    # method or free function. Most compilers can resolve `&Foo::bar`
    # against the surrounding template-deduced signature even when `bar`
    # is overloaded, but MSVC cannot, so when the name refers to an
    # overload set we wrap the address in a `static_cast` whose target
    # type *is* the signature:
    #
    #   non-overloaded:  &Foo::bar
    #   overloaded MSVC: static_cast<void(int, float)>(&Foo::bar)
    class FunctionPointer
      # Returns the address-of expression for `cursor`, optionally wrapped
      # in a disambiguating `static_cast`.
      def self.format(cursor, qualified_name, signature)
        reference = "&#{qualified_name}"
        return reference unless cast_required?(cursor, signature)

        "static_cast<#{signature[1...-1]}>(#{reference})"
      end

      # True when `cursor` shares its spelling with another overload
      # candidate in the same semantic parent — i.e. when MSVC would need
      # the cast to pick which overload `&qualified_name` refers to.
      def self.cast_required?(cursor, signature)
        return false unless signature
        return false unless cursor.kind == :cursor_function || cursor.static?

        parent = cursor.semantic_parent
        return false unless parent

        overload_count = 0
        parent.each(false) do |sibling, _|
          next unless overload_candidate?(cursor, sibling)

          overload_count += 1
          return true if overload_count > 1
        end

        false
      end
      private_class_method :cast_required?

      # A sibling counts as another overload of `cursor` only if the
      # spellings match AND the kinds are compatible. Free functions
      # collide with other free functions and function templates; static
      # methods collide with other methods (any static-ness) and method
      # templates. Non-static methods are excluded — they're addressed
      # as `&Class::method` and Rice dispatches them through a different
      # path that doesn't need disambiguation here.
      def self.overload_candidate?(cursor, sibling)
        return false unless sibling.spelling == cursor.spelling

        case cursor.kind
        when :cursor_function
          [:cursor_function, :cursor_function_template].include?(sibling.kind)
        when :cursor_cxx_method
          cursor.static? && [:cursor_cxx_method, :cursor_function_template].include?(sibling.kind)
        else
          false
        end
      end
      private_class_method :overload_candidate?
    end
  end
end
