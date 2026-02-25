# Extensions to ffi-clang's Type classes for ruby-bindgen.
#
# These methods help with namespace qualification of type spellings.
# Note: This is a partial solution - see rice.rb's type_spelling method
# for the full complexity of getting correct C++ type spellings.

module FFI
  module Clang
    module Types
      class Type
        # Monkey patch to expose template argument methods.
        # See https://github.com/ioquatix/ffi-clang/pull/93
        unless method_defined?(:num_template_arguments)
          Lib.attach_function :get_num_template_arguments, :clang_Type_getNumTemplateArguments, [Lib::CXType.by_value], :int
          Lib.attach_function :get_template_argument_as_type, :clang_Type_getTemplateArgumentAsType, [Lib::CXType.by_value, :uint], Lib::CXType.by_value

          def template_argument_type(index)
            Type.create Lib.get_template_argument_as_type(@type, index), @translation_unit
          end

          def num_template_arguments
            Lib.get_num_template_arguments(@type)
          end
        end

        # Returns the type spelling with full namespace qualification.
        #
        # Combines the declaration's qualified_name (which has the namespace) with
        # the spelling's template arguments (which qualified_name loses).
        #
        # Example: spelling="Vec<int>" + qualified_name="cv::Vec" -> "cv::Vec<int>"
        #
        # LIMITATIONS:
        # - Does not handle typedefs correctly (use type_spelling_typedef_or_alias)
        # - Does not handle class templates (use qualify_dependent_types_in_template_args)
        # - Does not handle dependent types (need 'typename' keyword)
        # - May return wrong result if canonical contains implementation cruft
        #
        # This is a building block used by rice.rb's type_spelling, not a complete solution.
        def fully_qualified_spelling
          decl = self.declaration
          return self.spelling if decl.kind == :cursor_no_decl_found

          spelling = self.spelling
          qualified = decl.qualified_name

          # Already fully qualified
          return spelling if spelling.include?('::') && spelling.start_with?(qualified.split('::').first)

          const_prefix = self.const_qualified? ? "const " : ""
          bare_spelling = spelling.sub(/^const\s+/, '')

          # Separate base name from template arguments
          if bare_spelling.include?('<')
            template_args = bare_spelling[/<.*/]
            base_spelling = bare_spelling.sub(/<.*/, '')
          else
            template_args = ''
            base_spelling = bare_spelling
          end

          # Find the namespace prefix from qualified_name that the spelling is missing.
          #
          # We split both the spelling and qualified_name into :: components, then
          # find where the spelling's first component appears in qualified_name.
          # Everything before that match point is the missing prefix.
          #
          # This handles C++ versioned inline namespaces. OpenCV uses macros like:
          #
          #   namespace cv { namespace dnn {
          #     namespace dnn4_v20241223 { class Net { ... }; }
          #     using namespace dnn4_v20241223;
          #   }}
          #
          # The programmer writes "dnn::Net" and libclang's qualified_name returns
          # "cv::dnn::dnn4_v20241223::Net". A naive end_with?("dnn::Net") fails
          # because the versioned component sits between "dnn" and "Net".
          #
          # By finding "dnn" at index 1 of ["cv", "dnn", "dnn4_v20241223", "Net"],
          # we know the missing prefix is "cv" and produce "cv::dnn::Net".
          base_parts = base_spelling.split('::')
          qualified_parts = qualified.split('::')
          match_idx = qualified_parts.index(base_parts.first)

          if match_idx && match_idx > 0
            prefix = qualified_parts[0...match_idx].join('::')
            "#{const_prefix}#{prefix}::#{bare_spelling}"
          elsif qualified.end_with?(base_spelling)
            "#{const_prefix}#{qualified}#{template_args}"
          else
            "#{const_prefix}#{bare_spelling}"
          end
        end
      end

      class Pointer
        def fully_qualified_spelling
          ptr_const = self.const_qualified? ? " const" : ""
          "#{self.pointee.fully_qualified_spelling}*#{ptr_const}"
        end
      end
    end
  end
end
