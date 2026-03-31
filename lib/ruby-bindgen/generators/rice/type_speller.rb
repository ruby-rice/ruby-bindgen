require_relative '../../type_pointer_formatter'

module RubyBindgen
  module Generators
    # Builds fully qualified C++ type spellings for generated Rice code and
    # applies the extra template/class qualification rules that libclang does
    # not handle on its own for emitted binding code.
    class TypeSpeller
      attr_writer :printing_policy

      def initialize(type_index:)
        @type_index = type_index
        clear
      end

      def clear
        @class_template_typedefs = {}
        @class_static_members = {}
      end

      # Get the fully qualified class/struct type used in generated bindings.
      #
      # Examples:
      #   outer::Locale::Facet<Locale>
      # becomes
      #   outer::Locale::Facet<outer::Locale>
      #
      # This goes through type_spelling(cursor.type) instead of cursor-specific
      # string surgery. A class cursor's first child can be an unrelated type_ref,
      # which makes first-match substitution double-qualify nested specializations
      # like outer::outer::Locale::Facet<outer::Locale>.
      def qualified_class_name(cursor)
        type_spelling(cursor.type)
      end

      # Get qualified display name for a cursor.
      # Qualifies any template arguments that need namespace prefixes.
      # Used for generating fully qualified names in enum constants, etc.
      def qualified_display_name(cursor)
        if cursor&.kind == :cursor_class_template
          template_arguments = template_parameter_arguments(cursor)
          return "#{cursor.qualified_name}<#{template_arguments.join(', ')}>" unless template_arguments.empty?
        end

        display_name = qualify_template_parameter_packs(cursor.qualified_display_name, cursor)

        # For members of template specializations, use the parent's type for qualification
        # e.g., TypeTraits<lowercase_type>::type needs lowercase_type qualified,
        # but cursor.type is just 'const int' which has no template args
        type = cursor.type
        parent = cursor.semantic_parent
        if parent && parent.type.num_template_arguments > 0
          type = parent.type
        end
        qualify_template_args(display_name, type,
                              ignored_names: template_parameter_names(cursor))
      end

      def type_spellings(cursor)
        cursor.type.arg_types.map do |arg_type|
          type_spelling(arg_type)
        end
      end

      # Returns a fully-qualified C++ type spelling suitable for use in generated Rice bindings.
      # Most type kinds are handled by Type#fully_qualified_name. This method only
      # intercepts elaborated types that need generator-level context:
      # - Class template types: fqn resolves template params, but template builders need them generic
      # - Typedefs inside class templates: need 'typename' keyword for dependent types
      # - Template instantiations: need qualify_template_args post-processing with TypeIndex
      def type_spelling(type)
        case type.kind
        when :type_pointer
          type_spelling_pointer(type)
        when :type_lvalue_ref
          "#{type_spelling(type.non_reference_type)} &"
        when :type_rvalue_ref
          "#{type_spelling(type.non_reference_type)} &&"
        when :type_constant_array
          "#{type_spelling(type.element_type)}[#{type.size}]"
        when :type_incomplete_array
          "#{type_spelling(type.element_type)}[]"
        when :type_elaborated
          type_spelling_elaborated(type)
        when :type_unexposed
          type_spelling_unexposed(type)
        else
          type.fully_qualified_name(@printing_policy)
        end
      end

      # Qualify nested typedefs from a class template in a type spelling
      # e.g., "std::reverse_iterator<iterator>" -> "std::reverse_iterator<cv::Mat_<_Tp>::iterator>"
      def qualify_class_template_typedefs(spelling, class_template)
        return spelling unless class_template&.kind == :cursor_class_template

        cache_key = class_template.usr
        typedef_info = @class_template_typedefs[cache_key] ||= begin
          names = []
          class_template.each(false) do |child|
            child_kind = child.kind
            if child_kind == :cursor_typedef_decl || child_kind == :cursor_type_alias_decl
              names << child.spelling
            end
          end
          { names: names, qualified_parent: class_template.qualified_display_name }
        end

        return spelling if typedef_info[:names].empty?

        result = spelling.dup
        qualified_parent = typedef_info[:qualified_parent]
        qualified_name = class_template.qualified_name
        display_name = class_template.display_name
        simple_name = class_template.spelling
        typedef_info[:names].each do |name|
          fully_qualified = /(?<![:\w])(?:typename\s+)?#{Regexp.escape(qualified_parent)}::#{Regexp.escape(name)}(?![:\w])/
          result = result.gsub(fully_qualified, "typename #{qualified_parent}::#{name}")

          if qualified_name && !qualified_name.empty? && qualified_name != qualified_parent
            qualified_without_args = /(?<![:\w])#{Regexp.escape(qualified_name)}::#{Regexp.escape(name)}(?![:\w])/
            result = result.gsub(qualified_without_args, "typename #{qualified_parent}::#{name}")
          end

          if display_name && !display_name.empty? && display_name != qualified_parent
            partially_qualified = /(?<![:\w])#{Regexp.escape(display_name)}::#{Regexp.escape(name)}(?![:\w])/
            result = result.gsub(partially_qualified, "typename #{qualified_parent}::#{name}")
          end

          if simple_name && !simple_name.empty?
            uninstantiated_class = /(?<![:\w])#{Regexp.escape(simple_name)}::#{Regexp.escape(name)}(?![:\w])/
            result = result.gsub(uninstantiated_class, "typename #{qualified_parent}::#{name}")
          end

          unqualified = /(?<![:\w])#{Regexp.escape(name)}(?![:\w])/
          result = result.gsub(unqualified, "typename #{qualified_parent}::#{name}")
        end

        result
      end

      # Qualify bare class members used as non-type template args.
      # Within a class like GPCPatchDescriptor, a member can write
      # Vec<double, nFeatures> but the generated binding code is outside the
      # class, so it needs Vec<double, GPCPatchDescriptor::nFeatures>.
      # qualify_template_args then handles qualifying GPCPatchDescriptor to
      # cv::optflow::GPCPatchDescriptor.
      #
      # Unscoped enum constants need the same treatment:
      #   FixedBuffer<int, Size>
      # becomes
      #   FixedBuffer<int, Tests::EnumSized<N>::Size>
      #
      # Class templates need their template parameters preserved:
      #   FixedBuffer<int, Size>
      # becomes
      #   FixedBuffer<int, Tests::StaticSized<N>::Size>
      def qualify_class_static_members(spelling, class_cursor)
        return spelling unless class_cursor

        parent_kind = class_cursor.kind
        return spelling unless parent_kind == :cursor_class_decl ||
                              parent_kind == :cursor_struct ||
                              parent_kind == :cursor_class_template

        cache_key = class_cursor.usr
        member_info = @class_static_members[cache_key] ||= begin
          names = []
          class_cursor.each(false) do |child|
            if child.kind == :cursor_variable
              names << child.spelling
            elsif child.kind == :cursor_enum_decl && !child.enum_scoped?
              child.each(false) do |enum_child|
                names << enum_child.spelling if enum_child.kind == :cursor_enum_constant_decl
              end
            end
          end
          qualified_parent = if parent_kind == :cursor_class_template
                               qualified_display_name(class_cursor)
                             else
                               class_cursor.qualified_name
                             end
          { names: names, qualified_parent: qualified_parent }
        end

        return spelling if member_info[:names].empty?

        result = spelling.dup
        qualified_parent = member_info[:qualified_parent]
        display_name = class_cursor.display_name
        member_info[:names].each do |name|
          if display_name && !display_name.empty? && display_name != qualified_parent
            partially_qualified = /(?<![:\w])#{Regexp.escape(display_name)}::#{Regexp.escape(name)}(?![:\w])/
            result = result.gsub(partially_qualified, "#{qualified_parent}::#{name}")
          end

          unqualified = /(?<![:\w])#{Regexp.escape(name)}(?![:\w])/
          result = result.gsub(unqualified, "#{qualified_parent}::#{name}")
        end

        result
      end

      def preserve_template_parameter_names(spelling, template_cursor)
        return spelling unless template_cursor&.kind == :cursor_class_template

        result = spelling.dup
        template_parameter_names(template_cursor).each do |name|
          qualified_name = @type_index.qualified_name_for(name)
          next if qualified_name.nil? || qualified_name == name

          result = result.gsub(/(?<![:\w])#{Regexp.escape(qualified_name)}(?![:\w])/, name)
        end
        result
      end

      private

      TEMPLATE_PARAMETER_KINDS = [:cursor_template_type_parameter,
                                  :cursor_non_type_template_parameter,
                                  :cursor_template_template_parameter].freeze

      def type_spelling_pointer(type)
        RubyBindgen::TypePointerFormatter.pointer_spelling(type) do |child_type|
          type_spelling(child_type)
        end
      end

      # Qualify template arguments in a type spelling
      # e.g., DataType<hfloat> -> DataType<cv::hfloat>
      # Collects qualified names from both original and canonical types
      def qualify_template_args(spelling, type, ignored_names: [])
        return spelling if spelling.nil? || !spelling.include?('<')

        qualifications = {}
        if type
          collect_type_qualifications(type, qualifications)
          collect_type_qualifications(type.canonical, qualifications)
        end

        spelling.scan(/(?<![:\w])([A-Z_a-z]\w*)(?!\w)/) do |match|
          simple_name = match[0]
          next if ignored_names.include?(simple_name)
          next if qualifications.key?(simple_name)

          qualified_name = @type_index.qualified_name_for(simple_name)
          qualifications[simple_name] = qualified_name if qualified_name && simple_name != qualified_name
        end

        result = spelling.dup
        qualifications.each do |simple_name, qualified_name|
          next if simple_name == qualified_name

          qualified_segments = qualified_name.split('::')
          if qualified_segments.length > 2
            (1...(qualified_segments.length - 1)).each do |index|
              partial_name = qualified_segments[index..].join('::')
              result = result.gsub(/(?<![:\w])#{Regexp.escape(partial_name)}(?![:\w])/, qualified_name)
            end
          end

          result = result.gsub(/(?<![:\w])#{Regexp.escape(simple_name)}(?!\w)/, qualified_name)
        end

        result
      end

      def template_parameter_names(cursor)
        return [] unless cursor

        cursor.find_by_kind(false, *TEMPLATE_PARAMETER_KINDS)
              .map(&:spelling)
              .reject(&:empty?)
      end

      def template_parameter_arguments(cursor)
        return [] unless cursor

        cursor.find_by_kind(false, *TEMPLATE_PARAMETER_KINDS)
              .filter_map do |template_parameter|
          name = template_parameter.spelling
          next if name.empty?

          declaration = template_parameter.extent.text
          declaration&.match?(/\.\.\.\s*#{Regexp.escape(name)}\b/) ? "#{name}..." : name
        end
      end

      def qualify_template_parameter_packs(spelling, cursor)
        return spelling unless cursor

        template_cursor = if cursor.kind == :cursor_class_template
                            cursor
                          elsif cursor.semantic_parent&.kind == :cursor_class_template
                            cursor.semantic_parent
                          end
        return spelling unless template_cursor

        pack_names = template_parameter_arguments(template_cursor)
                     .select { |argument| argument.end_with?('...') }
                     .map { |argument| argument.delete_suffix('...') }
        return spelling if pack_names.empty?

        result = spelling.dup
        pack_names.each do |name|
          result = result.gsub(/(?<![:\w])#{Regexp.escape(name)}(?!\.\.\.|[:\w])/, "#{name}...")
        end
        result
      end

      # Recursively collect simple_name -> qualified_name mappings from a type's template arguments
      def collect_type_qualifications(type, qualifications)
        return if type.nil? || type.kind == :type_invalid
        return unless type.num_template_arguments > 0

        type.num_template_arguments.times do |i|
          arg_type = type.template_argument_type(i)
          next if arg_type.kind == :type_invalid

          check_type = arg_type
          check_type = check_type.pointee while check_type.kind == :type_pointer

          decl = check_type.declaration
          if decl.kind != :cursor_no_decl_found
            simple_name = decl.spelling
            if TEMPLATE_PARAMETER_KINDS.include?(decl.kind)
              qualifications[simple_name] = simple_name unless simple_name.empty?
            else
              qualified_name = if decl.kind == :cursor_typedef_decl && decl.semantic_parent.kind == :cursor_class_template
                                 "#{decl.semantic_parent.qualified_display_name}::#{simple_name}"
                               else
                                 decl.qualified_name
                               end
              if !simple_name.empty? && simple_name != qualified_name
                qualifications[simple_name] = qualified_name
              end
            end
          end

          collect_type_qualifications(arg_type, qualifications)
        end
      end

      # Qualify dependent types within template arguments
      # e.g., "cv::Point_<typename DataType<_Tp>::channel_type>"
      #    -> "cv::Point_<typename cv::DataType<_Tp>::channel_type>"
      # Also handles nested template args such as:
      #   "typename Outer_<Outer_<T>>::type"
      # -> "typename Tests::Outer_<Tests::Outer_<T>>::type"
      #
      # The source range APIs are not available here because libclang only gives us
      # a type spelling string at this point, so we do a small balanced parse of the
      # dependent base name and then qualify the nested template args recursively.
      def qualify_dependent_types_in_template_args(spelling)
        return spelling unless spelling.include?('typename')

        result = String.new
        index = 0

        while (match = /\btypename\b/.match(spelling, index))
          result << spelling[index...match.end(0)]
          index = match.end(0)

          while index < spelling.length && spelling[index].match?(/\s/)
            result << spelling[index]
            index += 1
          end

          identifier_match = /\A([A-Za-z_][A-Za-z0-9_]*)/.match(spelling[index..])
          unless identifier_match
            result << spelling[index]
            index += 1
            next
          end

          class_name = identifier_match[1]
          name_end = index + class_name.length
          template_part, after_template = balanced_template_suffix(spelling, name_end)
          unless spelling[after_template, 2] == '::'
            result << spelling[index...after_template]
            index = after_template
            next
          end

          qualified_name = @type_index.qualified_name_for(class_name) || class_name
          qualified_template_part = if template_part.empty?
                                      ""
                                    else
                                      qualify_template_args(qualify_dependent_types_in_template_args(template_part), nil)
                                    end

          result << "#{qualified_name}#{qualified_template_part}::"
          index = after_template + 2
        end

        result << spelling[index..] if index < spelling.length
        result
      end

      def type_spelling_elaborated(type)
        decl = type.declaration

        case decl.kind
        when :cursor_class_template
          spelling = type.spelling
          outer_name = spelling.sub(/\s*<.*/, '')
          qualified = outer_name.match?(/\w+::/) ? spelling : spelling.sub(decl.spelling, decl.qualified_name)
          qualify_template_args(qualify_dependent_types_in_template_args(qualified), type)

        when :cursor_typedef_decl, :cursor_type_alias_decl
          if decl.semantic_parent.kind == :cursor_class_template
            const_prefix = type.const_qualified? ? "const " : ""
            parent = decl.semantic_parent
            display = qualified_display_name(parent)
            qualified = parent.qualified_name
            full_parent = if display.include?('<') && !display.start_with?(qualified)
                            "#{qualified}#{display[display.index('<')..]}"
                          else
                            display
                          end
            "#{const_prefix}typename #{full_parent}::#{decl.spelling}"
          else
            type.fully_qualified_name(@printing_policy)
          end

        when :cursor_no_decl_found
          spelling = type.spelling
          if spelling.include?('::')
            # Preserve already-qualified public aliases such as std::exception_ptr
            # instead of emitting canonical implementation-detail spellings.
            qualify_template_args(qualify_dependent_types_in_template_args(spelling), type)
          else
            qualify_template_args(type.fully_qualified_name(@printing_policy), type)
          end

        else
          qualify_template_args(type.fully_qualified_name(@printing_policy), type)
        end
      end

      def type_spelling_unexposed(type)
        decl = type.declaration
        spelling = type.spelling

        if decl.kind == :cursor_no_decl_found && spelling.include?('::')
          qualify_template_args(qualify_dependent_types_in_template_args(spelling), type)
        else
          type.fully_qualified_name(@printing_policy)
        end
      end

      def balanced_template_suffix(text, start_index)
        return ["", start_index] unless text[start_index] == '<'

        depth = 0
        index = start_index
        while index < text.length
          case text[index]
          when '<'
            depth += 1
          when '>'
            depth -= 1
            return [text[start_index..index], index + 1] if depth == 0
          end
          index += 1
        end

        ["", start_index]
      end
    end
  end
end
