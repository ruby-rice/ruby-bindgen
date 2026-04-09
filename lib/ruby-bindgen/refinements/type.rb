# Compat shim for Type#fully_qualified_name on LLVM < 21.
# On LLVM 21+, ffi-clang provides this natively via clang_getFullyQualifiedName.
# This implementation replicates the native behavior using declaration traversal.
#
# Known limitation: STL container typedefs (e.g., std::vector<T>::iterator)
# don't expand default template args. The output is valid C++ but shorter
# than native fqn (e.g., std::vector<Pixel>::iterator vs
# std::vector<Pixel, std::allocator<Pixel>>::iterator).

require_relative '../type_pointer_formatter'

module FFI
  module Clang
    module Types
      class Type
        unless Lib.respond_to?(:get_fully_qualified_name)
          def fully_qualified_name(policy, with_global_ns_prefix: false)
            result = fqn_impl(policy)
            with_global_ns_prefix ? "::#{result}" : result
          end
        end

        def fqn_impl(policy)
          case self.kind
          when :type_lvalue_ref
            "#{self.non_reference_type.fqn_impl(policy)} &"
          when :type_rvalue_ref
            "#{self.non_reference_type.fqn_impl(policy)} &&"
          when :type_pointer
            fqn_pointer(policy)
          when :type_constant_array
            "#{self.element_type.fqn_impl(policy)}[#{self.size}]"
          when :type_incomplete_array
            "#{self.element_type.fqn_impl(policy)}[]"
          when :type_elaborated
            fqn_elaborated(policy)
          when :type_record
            fqn_record
          else
            self.spelling
          end
        end

        # Handle pointer types. Walks the full pointer chain collecting
        # qualifiers, then qualifies the base type once and appends all stars.
        # Output matches native fqn: "int **", "const char *const", etc.
        def fqn_pointer(policy)
          RubyBindgen::TypePointerFormatter.pointer_spelling(self) do |child_type|
            child_type.fqn_impl(policy)
          end
        end

        def fqn_elaborated(policy)
          decl = self.declaration
          const_prefix = self.const_qualified? ? "const " : ""

          case decl.kind
          when :cursor_typedef_decl, :cursor_type_alias_decl
            # Preserve the typedef/alias name and qualify with namespace.
            spelling = self.unqualified_type.spelling
            qualified = decl.qualified_name

            if spelling.include?('::')
              # Has some qualification. For nested typedefs in template classes
              # (e.g., std::vector<Pixel>::iterator), qualify template args
              # using the parent type's fully qualified spelling.
              parent = decl.semantic_parent
              if parent.kind == :cursor_class_decl || parent.kind == :cursor_struct
                parent_type = parent.type
                parent_fqn = parent_type.fqn_impl(policy)
                member_name = decl.spelling
                "#{const_prefix}#{parent_fqn}::#{member_name}"
              else
                "#{const_prefix}#{spelling}"
              end
            elsif qualified
              "#{const_prefix}#{qualified}"
            else
              "#{const_prefix}#{spelling}"
            end

          when :cursor_enum_decl
            "#{const_prefix}#{decl.qualified_name}"

          else
            # Check if this is an alias template (e.g., AliasOptional<int> -> Optional<int>).
            # The elaborated spelling preserves the alias, but fqn_record would resolve
            # to the underlying type. Use spelling when it's already qualified.
            unqual = self.unqualified_type.spelling
            if unqual.include?('::') && decl.spelling != unqual.sub(/<.*/, '').split('::').last
              "#{const_prefix}#{unqual}"
            else
              base = fqn_record
              if self.const_qualified? && !base.start_with?("const ")
                "const #{base}"
              else
                base
              end
            end
          end
        end

        # Qualify a record type (class/struct) using its declaration's type spelling.
        # decl.type.spelling suppresses inline namespaces and includes template args,
        # matching native fqn behavior. Falls back to qualified_name + spelling args
        # for dependent types.
        def fqn_record
          decl = self.declaration
          return self.spelling if decl.kind == :cursor_no_decl_found

          const_prefix = self.const_qualified? ? "const " : ""

          # decl.type.spelling gives us the right qualification (no inline ns, with template args)
          decl_spelling = decl.type.spelling
          if decl_spelling && !decl_spelling.empty? && decl_spelling.include?('::')
            # For concrete template types, recursively qualify template args
            n = self.num_template_arguments
            if n > 0
              base = decl_spelling.sub(/<.*/, '')
              template_args = fqn_template_args(nil)
              "#{const_prefix}#{base}#{template_args}"
            else
              "#{const_prefix}#{decl_spelling}"
            end
          else
            # Fallback for types where decl.type.spelling is unqualified
            qualified = decl.qualified_name
            bare_spelling = self.unqualified_type.spelling
            template_args = bare_spelling.include?('<') ? bare_spelling[/<.*/] : ''
            "#{const_prefix}#{qualified}#{template_args}"
          end
        end

        # Build qualified template argument string by recursing into each
        # template argument type rather than relying on unqualified spelling.
        def fqn_template_args(policy)
          n = self.num_template_arguments
          return '' unless n > 0

          # Extract original args from spelling for non-type template params
          spelling_args = parse_template_args_from_spelling

          args = (0...n).map do |i|
            arg_type = self.template_argument_type(i)
            if arg_type.kind == :type_invalid
              # Non-type template arg (e.g., int N=3) — use from spelling
              spelling_args ? spelling_args[i] : nil
            else
              arg_type.fqn_impl(policy)
            end
          end.compact

          return '' if args.empty?
          "<#{args.join(', ')}>"
        end

        # Parse template arguments from the type's spelling string.
        # Handles nested angle brackets correctly.
        def parse_template_args_from_spelling
          bare = self.unqualified_type.spelling
          start = bare.index('<')
          return nil unless start

          # Extract content between outermost < >
          depth = 0
          args = []
          current = +""
          bare[start + 1..].each_char do |c|
            case c
            when '<'
              depth += 1
              current << c
            when '>'
              if depth == 0
                args << current.strip unless current.strip.empty?
                break
              else
                depth -= 1
                current << c
              end
            when ','
              if depth == 0
                args << current.strip
                current = +""
              else
                current << c
              end
            else
              current << c
            end
          end
          args
        end
      end
    end
  end
end
