require 'set'

module RubyBindgen
  # Generates the ordered list of name strings a cursor could plausibly be
  # referenced as in a YAML symbols entry. Pure name enumeration — owns no
  # tables and makes no policy decisions. Consumers (Symbols, Namer) feed
  # the result through their own lookup tables.
  #
  # The list spans:
  #   * libclang's qualified_name (with anonymous scopes stripped)
  #   * parent.type.spelling-based qualified name (collapses inline namespaces)
  #   * display_name forms with template arguments
  #   * a "specialized" display rebuilt from libclang template-arg APIs (so
  #     Outer::takeValue<7>() matches even when display_name is takeValue<>())
  #   * parameter-list forms (clang preferred / fully-qualified / canonical)
  #     for callable cursors, against every qualified-name form above
  #   * cursor.spelling as the bare-name fallback (last so it does not
  #     shadow a more-specific user rule)
  class SymbolCandidates
    include Enumerable

    # Canonicalize whitespace in a signature so user-supplied spellings match
    # libclang's. Used by table consumers to keep keys and lookups aligned.
    def self.normalize_signature(str)
      str
        .gsub(/\s+/, ' ')
        .gsub(/\s*\*/, '*')
        .gsub(/\s*&/, '&')
        .strip
    end

    def initialize(cursor)
      @cursor = cursor
    end

    # Yield each candidate string in priority order (most-specific first).
    # Consumers stop on the first match, so qualified user rules win over
    # bare-name fallbacks like the built-in operator mappings.
    def each
      return enum_for(:each) unless block_given?

      seen = Set.new
      qualified_names = qualified_name_forms

      qualified_names.each do |name|
        yield name if seen.add?(name)
      end

      # Template display candidates: display_name carries template args, e.g.
      # "DataType<hfloat>" or "saturate_cast<hfloat>(uchar)". Also rebuild a
      # specialized display from libclang template-arg APIs to recover names
      # that display_name leaves abbreviated, e.g. takeValue<>() -> takeValue<7>().
      display = @cursor.display_name
      if display != @cursor.spelling
        qualified_names.each do |qn|
          yield display if seen.add?(display)
          qualified_display = sub_last(qn, @cursor.spelling, display)
          yield qualified_display if seen.add?(qualified_display)
        end

        specialized_display = specialized_template_display_name(display)
        if specialized_display && specialized_display != display
          qualified_names.each do |qn|
            yield specialized_display if seen.add?(specialized_display)
            fq_qualified_display = sub_last(qn, @cursor.spelling, specialized_display)
            yield fq_qualified_display if seen.add?(fq_qualified_display)
          end
        end
      end

      # Parameter-list forms for callable cursors. Each list is built three
      # ways because libclang spells the same parameter type differently in
      # different contexts:
      #   - arg_type.spelling: clang's preferred form, often the typedef
      #   - fully_qualified_name: fully namespace-qualified
      #   - canonical.spelling: post-typedef canonical type
      # Users may write any of these forms in their YAML; emit them all.
      if @cursor.type.is_a?(FFI::Clang::Types::Function)
        parameter_lists = []
        parameter_lists << (0...@cursor.type.args_size).map { |i| @cursor.type.arg_type(i).spelling }.join(", ")
        parameter_lists << (0...@cursor.type.args_size).map { |i| @cursor.type.arg_type(i).fully_qualified_name(@cursor.printing_policy) }.join(", ")
        parameter_lists << (0...@cursor.type.args_size).map { |i| @cursor.type.arg_type(i).canonical.spelling }.join(", ")

        parameter_lists.uniq.each do |param_types|
          bare = "#{@cursor.spelling}(#{param_types})"
          yield bare if seen.add?(bare)
          qualified_names.each do |qn|
            candidate = "#{qn}(#{param_types})"
            yield candidate if seen.add?(candidate)
          end
        end
      end

      yield @cursor.spelling if seen.add?(@cursor.spelling)

      $stderr.puts "Candidates for #{@cursor.spelling}: #{seen.to_a.inspect}" if ENV['BINDGEN_DEBUG_SYMBOLS']
    end

    private

    # Enumerate qualified-name forms a cursor can be referred to by.
    #
    # Returns at minimum the libclang qualified_name (with anonymous scope
    # segments dropped so enum constants match Outer::Value rather than
    # Outer::(unnamed enum at ...)::Value).
    #
    # For class members, also includes a qualified name built from the
    # parent's type spelling. Type spellings collapse inline namespaces, so
    # cv::dnn::dnn4_v20241223::Layer::init also gets a cv::dnn::Layer::init
    # candidate that matches YAML entries omitting the inline namespace.
    def qualified_name_forms
      forms = [normalized_qualified_name].compact.uniq

      parent = @cursor.semantic_parent
      if parent && [:cursor_class_decl, :cursor_struct, :cursor_class_template].include?(parent.kind)
        type_qualified = "#{parent.type.spelling}::#{@cursor.spelling}"
        forms << type_qualified unless forms.include?(type_qualified)
      end

      forms
    end

    # Use libclang's semantic qualified name directly, but drop anonymous
    # scope segments so enum constants still match entries like Outer::Value
    # instead of Outer::(unnamed enum at ... )::Value.
    def normalized_qualified_name
      qualified_name = @cursor.qualified_name
      return @cursor.spelling if qualified_name.nil? || qualified_name.empty?

      qualified_name
        .split('::')
        .reject { |segment| segment.start_with?('(') }
        .join('::')
    rescue ArgumentError
      @cursor.spelling
    end

    # Rebuild a template specialization display name using cursor template
    # arguments. Type args are fully qualified semantically, while written
    # display text is preserved for integral or other non-type args that
    # libclang does not expose as names.
    #
    # Examples:
    #   `Holder<Tag, 7>`     becomes  `Holder<Outer::Tag, 7>`
    #   `takeValue<>()`      becomes  `takeValue<7>()`
    def specialized_template_display_name(display)
      args = template_argument_display_values(display)
      return nil if args.nil? || args.empty? || args.any?(&:nil?)

      sub_template_args(display, "<#{args.join(', ')}>")
    end

    def template_argument_display_values(display)
      n = @cursor.num_template_arguments
      return nil unless n > 0

      written_args = template_argument_texts(display)
      (0...n).map do |index|
        case @cursor.template_argument_kind(index)
        when :template_argument_type
          @cursor.template_argument_type(index).fully_qualified_name(@cursor.printing_policy)
        when :template_argument_integral
          written_args[index] || @cursor.template_argument_value(index).to_s
        else
          written_args[index]
        end
      end
    end

    def template_argument_texts(display)
      start = display.index('<')
      return [] unless start

      depth = 0
      args_start = start + 1
      args_end = nil

      (start...display.length).each do |index|
        depth += 1 if display[index] == '<'
        depth -= 1 if display[index] == '>'
        if depth.zero?
          args_end = index
          break
        end
      end
      return [] unless args_end

      args_text = display[args_start...args_end]
      return [] if args_text.nil? || args_text.empty?

      split_template_arguments(args_text)
    end

    # Split a template-argument list, respecting nested <>, (), [], {} and
    # quoted literals. The naive `split(',')` would mangle nested types like
    # `std::pair<int, std::vector<int, std::allocator<int>>>` and string
    # literals containing commas.
    def split_template_arguments(args_text)
      result = []
      current = String.new
      angle_depth = 0
      paren_depth = 0
      bracket_depth = 0
      brace_depth = 0
      quote = nil
      escaped = false

      args_text.each_char do |char|
        current << char

        if quote
          if escaped
            escaped = false
          elsif char == '\\'
            escaped = true
          elsif char == quote
            quote = nil
          end
          next
        end

        case char
        when '"', "'"
          quote = char
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
        when ','
          if angle_depth.zero? && paren_depth.zero? && bracket_depth.zero? && brace_depth.zero?
            current.chop!
            piece = current.strip
            result << piece unless piece.empty?
            current = String.new
          end
        end
      end

      piece = current.strip
      result << piece unless piece.empty?
      result
    end

    # Replace the first balanced <...> group in str with replacement.
    # Handles nested angle brackets like DataType<Vec<float, 3>>.
    def sub_template_args(str, replacement)
      start = str.index('<')
      return str unless start

      depth = 0
      (start...str.length).each do |i|
        depth += 1 if str[i] == '<'
        depth -= 1 if str[i] == '>'
        if depth == 0
          return str[0...start] + replacement + str[(i + 1)..]
        end
      end
      str
    end

    # Replace the last occurrence of `target` in `str` with `replacement`.
    # Used when building qualified candidates for constructors, where the
    # spelling (e.g. "DataType") appears both as namespace and method name.
    def sub_last(str, target, replacement)
      i = str.rindex(target)
      return str unless i
      str[0...i] + replacement + str[(i + target.length)..]
    end
  end
end
