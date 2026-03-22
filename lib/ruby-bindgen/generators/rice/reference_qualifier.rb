module RubyBindgen
  module Generators
    # Qualifies source-written references using libclang spans for location and
    # cursor metadata for the replacement text. This preserves the original
    # written expression everywhere except the exact references that need
    # namespace or class qualification once emitted outside their source scope.
    class ReferenceQualifier
      # Qualify names inside source-written text without trusting the source
      # range text itself for replacement content.
      #
      # Examples:
      #   text = 'helper("helper")'
      #   => 'quoted::helper("helper")'
      #
      #   text = 'Holder<Tag>::value'
      #   => 'QualifiedDefaults::Holder<QualifiedDefaults::Tag>::value'
      def qualify_source_references(root_cursor, source_text, source_text_offset, qualify_decl_refs: true, substitutions: {})
        range_replacements = []
        type_fallbacks = []

        root_cursor.find_by_kind(true, :cursor_type_ref, :cursor_template_ref) do |type_ref|
          ref = type_ref.referenced
          next unless ref && ref.kind != :cursor_invalid_file

          simple_name = ref.spelling
          if simple_name && substitutions.key?(simple_name)
            range = type_ref.reference_name_range([:want_qualifier, :want_template_args, :want_single_piece])
            replacement = source_range_replacement(source_text, source_text_offset, range, substitutions[simple_name])
            if replacement
              range_replacements << replacement.merge(kind: :type)
              next
            end
          end

          # Template type parameters stay visible by bare name in generated
          # template code, so they should not be qualified here.
          next if [:cursor_template_type_parameter, :cursor_template_template_parameter].include?(ref.kind)

          begin
            is_dependent_typedef = ref.kind == :cursor_typedef_decl && ref.semantic_parent.kind == :cursor_class_template
            qualified_name = if is_dependent_typedef
                               "#{ref.semantic_parent.qualified_display_name}::#{ref.spelling}"
                             else
                               ref.qualified_name
                             end
            simple_name = ref.spelling
            next if simple_name.nil? || simple_name.empty?
            next if simple_name == qualified_name

            range = type_ref.reference_name_range([:want_qualifier, :want_template_args, :want_single_piece])
            replacement = source_range_replacement(source_text, source_text_offset, range)
            if replacement
              start_index = replacement[:start_offset] - source_text_offset
              end_index = replacement[:end_offset] - source_text_offset
              start_index = expand_name_start_to_qualifier(source_text, start_index)
              replacement = replacement.merge(start_offset: source_text_offset + start_index)
              span_text = source_text.byteslice(start_index, end_index - start_index)
              trailing_scope = source_text.byteslice(end_index, 2).to_s == '::'

              replacement_name = if ref.kind == :cursor_class_template && trailing_scope && !span_text.include?('<')
                                   ref.qualified_display_name
                                 else
                                   qualified_name
                                 end
              replacement_text = replacement_from_name_span(span_text, simple_name, replacement_name)
              if is_dependent_typedef && replacement_text && !trailing_scope &&
                 !preceded_by_typename?(source_text, start_index)
                replacement_text = "typename #{replacement_text}"
              end

              if replacement_text && replacement_text != span_text
                range_replacements << replacement.merge(replacement: replacement_text, kind: :type)
                next
              end
            end

            type_fallbacks << [ref, simple_name, qualified_name, is_dependent_typedef]
          rescue ArgumentError
            # Skip if we can't get qualified name (e.g., invalid cursor)
          end
        end

        decl_fallbacks = []
        if qualify_decl_refs
          decl_refs = root_cursor.find_by_kind(true, :cursor_decl_ref_expr).to_a
          decl_refs = [root_cursor] + decl_refs if root_cursor.kind == :cursor_decl_ref_expr
          decl_refs.each do |decl_ref|
            ref = decl_ref.referenced
            next unless ref && ref.kind != :cursor_invalid_file

            begin
              simple_name = ref.spelling
              next if simple_name.nil? || simple_name.empty?

              if substitutions.key?(simple_name)
                range = if decl_ref.extent.text.include?('<')
                          decl_ref.spelling_name_range(0)
                        else
                          decl_ref.reference_name_range([:want_qualifier, :want_template_args, :want_single_piece])
                        end
                replacement = source_range_replacement(source_text, source_text_offset, range, substitutions[simple_name])
                if replacement
                  range_replacements << replacement.merge(kind: :decl)
                  next
                end
              end

              next if ref.kind == :cursor_non_type_template_parameter

              if ref.kind == :cursor_cxx_method
                next if source_text.match?(/::#{Regexp.escape(simple_name)}\s*\(/)
              end

              qualified_name = if ref.kind == :cursor_enum_constant_decl &&
                                  ref.semantic_parent.kind == :cursor_enum_decl &&
                                  !ref.semantic_parent.enum_scoped?
                                 enum_parent = ref.semantic_parent.semantic_parent
                                 if enum_parent && enum_parent.kind == :cursor_namespace
                                   "#{enum_parent.qualified_name}::#{simple_name}"
                                 elsif ref.semantic_parent.anonymous? &&
                                       enum_parent && enum_parent.kind != :cursor_translation_unit
                                   "#{enum_parent.qualified_name}::#{simple_name}"
                                 else
                                   ref.qualified_name
                                 end
                               elsif ref.semantic_parent.kind == :cursor_class_template
                                 "#{ref.semantic_parent.qualified_display_name}::#{simple_name}"
                               else
                                 ref.qualified_name
                               end

              next if simple_name == qualified_name
              next if qualified_name.start_with?('::')
              next unless qualified_name.end_with?(simple_name)

              range = if decl_ref.extent.text.include?('<')
                        decl_ref.spelling_name_range(0)
                      else
                        decl_ref.reference_name_range([:want_qualifier, :want_template_args, :want_single_piece])
                      end
              replacement = source_range_replacement(source_text, source_text_offset, range)
              if replacement
                start_index = replacement[:start_offset] - source_text_offset
                end_index = replacement[:end_offset] - source_text_offset
                span_text = source_text.byteslice(start_index, end_index - start_index)
                replacement_text = replacement_from_name_span(span_text, simple_name, qualified_name)
                if replacement_text && replacement_text != span_text
                  range_replacements << replacement.merge(replacement: replacement_text, kind: :decl)
                  next
                end
              end

              decl_fallbacks << [simple_name, qualified_name]
            rescue ArgumentError
              # Skip if we can't get qualified name
            end
          end

          decl_replacements = range_replacements.select { |replacement| replacement[:kind] == :decl }
          range_replacements.reject! do |replacement|
            replacement[:kind] == :type &&
              decl_replacements.any? do |decl_replacement|
                decl_replacement[:start_offset] <= replacement[:start_offset] &&
                  decl_replacement[:end_offset] >= replacement[:end_offset]
              end
          end
        end

        source_text = apply_source_replacements(source_text, source_text_offset, range_replacements) unless range_replacements.empty?

        type_fallbacks.each do |type_fallback|
          ref, simple_name, qualified_name, is_dependent_typedef = type_fallback
          source_text = fallback_qualify_type_reference(source_text, ref, simple_name, qualified_name, is_dependent_typedef)
        end

        decl_fallbacks.each do |decl_fallback|
          simple_name, qualified_name = decl_fallback
          source_text = fallback_qualify_declaration_reference(source_text, simple_name, qualified_name)
        end

        source_text
      end

      # Expand the written name span to the desired fully qualified form
      # without dropping template args or clobbering existing qualifiers.
      #
      # Examples:
      #   span_text       = 'helper'
      #   simple_name     = 'helper'
      #   qualified_name  = 'quoted::helper'
      #   => 'quoted::helper'
      #
      #   span_text       = 'makePtr<inner::IndexParams>'
      #   simple_name     = 'makePtr'
      #   qualified_name  = 'outer::makePtr'
      #   => 'outer::makePtr<inner::IndexParams>'
      #
      #   span_text       = 'PerfLevel::SLOW'
      #   simple_name     = 'SLOW'
      #   qualified_name  = 'multiline::PerfLevel::SLOW'
      #   => 'multiline::PerfLevel::SLOW'
      def replacement_from_name_span(span_text, simple_name, qualified_name)
        return qualified_name if span_text == simple_name
        return qualified_name if span_text.include?('::') && span_text.end_with?(simple_name)
        return span_text.sub(/\A#{Regexp.escape(simple_name)}/, qualified_name) if span_text.start_with?(simple_name)

        nil
      end

      # Find the byte offset of the declaration's top-level default-value `=`.
      #
      # Examples:
      #   'FILE* stream = stdout'
      #   => offset of the `=` before stdout
      #
      #   'template<typename U = int> class Container = Box'
      #   => offset of the `=` before Box, not the inner `= int`
      #
      # Nested delimiters are skipped so `=` inside template parameter lists,
      # function types, arrays, and braced expressions does not get mistaken for
      # the declaration's own default separator.
      def top_level_default_separator_offset(text)
        return nil if text.nil? || text.empty?

        angle_depth = 0
        paren_depth = 0
        bracket_depth = 0
        brace_depth = 0
        in_single_quote = false
        in_double_quote = false
        escaped = false
        byte_offset = 0

        text.each_char do |char|
          if in_single_quote || in_double_quote
            if escaped
              escaped = false
            elsif char == '\\'
              escaped = true
            elsif in_single_quote && char == "'"
              in_single_quote = false
            elsif in_double_quote && char == '"'
              in_double_quote = false
            end
          else
            case char
            when "'"
              in_single_quote = true
            when '"'
              in_double_quote = true
            when '<'
              angle_depth += 1
            when '>'
              angle_depth -= 1 if angle_depth > 0
            when '('
              paren_depth += 1
            when ')'
              paren_depth -= 1 if paren_depth > 0
            when '['
              bracket_depth += 1
            when ']'
              bracket_depth -= 1 if bracket_depth > 0
            when '{'
              brace_depth += 1
            when '}'
              brace_depth -= 1 if brace_depth > 0
            when '='
              if angle_depth.zero? && paren_depth.zero? && bracket_depth.zero? && brace_depth.zero?
                return byte_offset
              end
            end
          end

          byte_offset += char.bytesize
        end

        nil
      end

      # Split a declaration at its top-level default-value '=' and return both
      # the written default text and its byte offset in the source file.
      #
      # Examples:
      #   'FILE* stream = stdout'
      #   => ['stdout', <offset of the s in stdout>]
      #
      #   "PerfLevel level\n      = PerfLevel::SLOW"
      #   => ['PerfLevel::SLOW', <offset of the P in PerfLevel::SLOW>]
      #
      #   'typename U = Box<Tag>'
      #   => ['Box<Tag>', <offset of the B in Box<Tag>>]
      #
      #   'template<typename U = int> class Container = Box'
      #   => ['Box', <offset of the B in Box>]
      #
      # This is text extraction only. Qualification happens later using cursor
      # information so we do not lose semantic information for either function
      # defaults or template parameter defaults.
      def extract_default_text(param)
        param_extent = param.extent.text
        return nil unless param_extent

        separator_offset = top_level_default_separator_offset(param_extent)
        return nil unless separator_offset

        before = param_extent.byteslice(0, separator_offset)
        after = param_extent.byteslice((separator_offset + 1)..-1).to_s

        leading_whitespace = after[/\A\s*/] || ""
        default_text = after.delete_prefix(leading_whitespace)
        return nil if default_text.empty?

        default_text_offset = param.extent.start.offset + before.bytesize + 1 + leading_whitespace.bytesize
        [default_text, default_text_offset]
      end

      private

      # Convert a libclang source range into offsets relative to the extracted
      # default-expression text so semantic replacements can be applied safely.
      #
      # Example:
      #   text        = 'makePtr<inner::IndexParams>()'
      #   base_offset = 1200
      #   range       = source range for 'makePtr<inner::IndexParams>'
      #
      # Returns offsets relative to the file:
      #   { start_offset: 1200, end_offset: 1228, replacement: ... }
      #
      # Those offsets are later converted back into indexes relative to `text`
      # before patching only that exact span.
      def source_range_replacement(text, base_offset, range, replacement = nil)
        return nil if range.nil? || range.null?

        start_offset = range.start.offset
        end_offset = range.end.offset
        text_end_offset = base_offset + text.bytesize
        return nil if start_offset < base_offset || end_offset > text_end_offset || end_offset < start_offset

        { start_offset: start_offset, end_offset: end_offset, replacement: replacement }
      rescue ArgumentError
        nil
      end

      # Apply non-overlapping source replacements from right to left so earlier
      # offsets remain valid while rewriting a default expression.
      #
      # Example:
      #   text = 'helper("helper")'
      #   replacements = [{start_offset: ..., end_offset: ..., replacement: 'quoted::helper'}]
      #
      # Produces:
      #   'quoted::helper("helper")'
      #
      # The string literal stays untouched because only the decl-ref span is replaced.
      def apply_source_replacements(text, base_offset, replacements)
        replacements
          .uniq { |r| [r[:start_offset], r[:end_offset], r[:replacement]] }
          .sort_by { |r| -r[:start_offset] }
          .reduce(text.dup) do |result, replacement|
            start_index = replacement[:start_offset] - base_offset
            end_index = replacement[:end_offset] - base_offset
            result.byteslice(0, start_index) +
              replacement[:replacement] +
              result.byteslice(end_index..-1).to_s
          end
      end

      # Check whether the source text immediately before a replacement span already
      # ends with `typename`, so we do not emit `typename typename Foo::Bar`.
      #
      # Examples:
      #   text        = 'typename SearchIndex<Distance>::ElementType()'
      #   start_index = index of the S in SearchIndex
      #   => true
      #
      #   text        = 'SearchIndex<Distance>::ElementType()'
      #   start_index = index of the S in SearchIndex
      #   => false
      def preceded_by_typename?(text, start_index)
        text.byteslice(0, start_index).to_s.match?(/(?:\A|[^\w:])typename\s+\z/)
      end

      # Extend a name-token span backward to include a written qualifier chain.
      #
      # Examples:
      #   text        = 'makePtr<inner::IndexParams>()'
      #   start_index = index of the I in IndexParams
      #   => index of the i in inner
      #
      #   text        = 'SearchIndex<Distance>::ElementType()'
      #   start_index = index of the E in ElementType
      #   => index of the S in SearchIndex
      def expand_name_start_to_qualifier(text, start_index)
        index = start_index

        loop do
          break unless index >= 2 && text.byteslice(index - 2, 2) == '::'

          segment_end = index - 2
          cursor = segment_end - 1
          break if cursor.negative?

          if text[cursor] == '>'
            depth = 0
            while cursor >= 0
              case text[cursor]
              when '>'
                depth += 1
              when '<'
                depth -= 1
                break if depth.zero?
              end
              cursor -= 1
            end
            break if cursor.negative?
            cursor -= 1
          end

          while cursor >= 0 && text[cursor].match?(/[A-Za-z0-9_]/)
            cursor -= 1
          end

          segment_start = cursor + 1
          break if segment_start == segment_end

          index = segment_start
        end

        index
      end

      def fallback_qualify_type_reference(text, ref, simple_name, qualified_name, is_dependent_typedef)
        # Replace unqualified occurrences (negative lookbehind avoids already-qualified names)
        result = text.gsub(/(?<!::)\b#{Regexp.escape(simple_name)}\b/, qualified_name)

        # Replace partially-qualified names (e.g., flann::Foo -> cv::flann::Foo)
        # Match any prefix::simple_name that isn't already fully qualified
        result = result.gsub(/(?<!\w)(\w+(?:::\w+)*)::#{Regexp.escape(simple_name)}\b/) do |match|
          match == qualified_name ? match : qualified_name
        end

        # For class template refs used as qualifiers (before ::) without explicit template args,
        # insert template parameters (e.g., CompositeIndex:: -> CompositeIndex<Distance>::)
        if ref.kind == :cursor_class_template
          display_name = ref.qualified_display_name
          result = result.gsub(/#{Regexp.escape(qualified_name)}(?=\s*::)/, display_name)
        end

        # Add 'typename' for dependent typedef names used as types (not as qualifiers before ::)
        # e.g., SearchIndex<Distance>::ElementType() needs typename, but Vec3Type::all() does not
        if is_dependent_typedef
          result = result.gsub(/(?<!typename )#{Regexp.escape(qualified_name)}(?!\s*::)/, "typename #{qualified_name}")
        end

        result
      end

      def fallback_qualify_declaration_reference(text, simple_name, qualified_name)
        # Apply qualification (negative lookbehind avoids double-qualifying)
        result = text.gsub(/(?<!::)\b#{Regexp.escape(simple_name)}\b/, qualified_name)

        # Replace partially-qualified names (e.g., fisheye::CALIB_FIX_INTRINSIC -> cv::fisheye::CALIB_FIX_INTRINSIC)
        # Match any prefix::simple_name that isn't already fully qualified
        result.gsub(/(?<!\w)(\w+(?:::\w+)*)::#{Regexp.escape(simple_name)}\b/) do |match|
          match == qualified_name ? match : qualified_name
        end
      end
    end
  end
end
