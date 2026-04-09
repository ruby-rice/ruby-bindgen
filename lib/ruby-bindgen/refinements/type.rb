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
            # Class declarations, template instantiations, etc.
            base = fqn_record
            if self.const_qualified? && !base.start_with?("const ")
              "const #{base}"
            else
              base
            end
          end
        end

        # Qualify a record type (class/struct) using its declaration's qualified_name.
        # qualified_name includes inline namespace components (e.g.,
        # cv::dnn::dnn4_v20241223::Net) matching native fqn behavior.
        def fqn_record
          decl = self.declaration
          return self.spelling if decl.kind == :cursor_no_decl_found

          qualified = decl.qualified_name
          const_prefix = self.const_qualified? ? "const " : ""
          bare_spelling = self.unqualified_type.spelling

          # qualified_name drops template args — recover them from spelling
          template_args = bare_spelling.include?('<') ? bare_spelling[/<.*/] : ''

          "#{const_prefix}#{qualified}#{template_args}"
        end
      end
    end
  end
end
