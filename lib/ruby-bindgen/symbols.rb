module RubyBindgen
  class Symbols
    def initialize(config = {})
      @exact = {}
      @regex = []

      (config[:skip] || []).each do |name|
        add_entry(name, skip: true)
      end

      (config[:versions] || {}).each do |version, names|
        names.each do |name|
          add_entry(name, version: version)
        end
      end

      (config[:overrides] || {}).each do |name, signature|
        add_entry(name.to_s, signature: signature)
      end
    end

    # Build candidate names for a cursor for symbol lookup.
    # Returns candidates in priority order: exact names first, then with params.
    # Includes display_name-based candidates for template specializations.
    def build_candidates(cursor)
      qualified_name = cursor.spelling
      parent = cursor.semantic_parent
      while parent && !parent.kind.nil? &&
            parent.kind != :cursor_translation_unit &&
            !parent.kind.to_s.start_with?("cursor_invalid")
        # Skip anonymous parents (clang spells them as "(unnamed enum at ...)" etc.)
        qualified_name = "#{parent.spelling}::#{qualified_name}" if parent.spelling && !parent.spelling.empty? && !parent.spelling.start_with?('(')
        parent = parent.semantic_parent
      end

      qualified_names = [qualified_name]

      # For class members, also build a qualified name from the parent's type spelling.
      # The type system resolves through inline namespaces (e.g., cv::debug_build_guard::_OutputArray
      # becomes cv::_OutputArray), so this candidate matches YAML entries that omit inline namespaces.
      parent = cursor.semantic_parent
      if parent && [:cursor_class_decl, :cursor_struct, :cursor_class_template].include?(parent.kind)
        type_qualified = "#{parent.type.spelling}::#{cursor.spelling}"
        qualified_names << type_qualified unless qualified_names.include?(type_qualified)
      end

      candidates = [cursor.spelling] + qualified_names

      # Add display_name-based candidates for template specializations
      # (display_name includes template args, e.g., "DataType<hfloat>" or "saturate_cast<hfloat>(uchar)")
      display = cursor.display_name
      if display != cursor.spelling
        qualified_names.each do |qn|
          qualified_display = sub_last(qn, cursor.spelling, display)
          candidates << display unless candidates.include?(display)
          candidates << qualified_display unless candidates.include?(qualified_display)
        end

        specialized_display = specialized_template_display_name(cursor, display)
        if specialized_display && specialized_display != display
          qualified_names.each do |qn|
            fq_qualified_display = sub_last(qn, cursor.spelling, specialized_display)
            candidates << specialized_display unless candidates.include?(specialized_display)
            candidates << fq_qualified_display unless candidates.include?(fq_qualified_display)
          end
        end
      end

      add_parameter_candidates(candidates, cursor, qualified_names) if cursor.type.respond_to?(:args_size)

      if ENV['BINDGEN_DEBUG_SYMBOLS']
        $stderr.puts "Candidates for #{cursor.spelling}: #{candidates.inspect}"
      end

      candidates
    end

    # Look up a symbol by trying each candidate in order.
    # Returns a SymbolEntry or nil.
    def lookup(candidates)
      candidates.each do |name|
        result = @exact[normalize_signature(name)]
        return result if result
      end

      @regex.each do |pattern, entry|
        candidates.each do |name|
          return entry if pattern.match?(normalize_signature(name))
        end
      end
      nil
    end

    # Check if a cursor should be skipped based on symbols config.
    def skip?(cursor)
      entry = lookup(build_candidates(cursor))
      entry&.skip? || false
    end

    # Check if a type spelling matches any skip symbol using word boundaries.
    # Used as a fallback for dependent/unexposed types where no declaration is available.
    def skip_spelling?(spelling)
      @exact.each do |key, entry|
        next unless entry.skip?
        simple_name = key.split('::').last
        return true if spelling.match?(/\b#{Regexp.escape(simple_name)}\b/)
      end
      @regex.each do |pattern, entry|
        next unless entry.skip?
        return true if pattern.match?(spelling)
      end
      false
    end

    # Returns the version guard value for a cursor, or nil if not version-guarded.
    def version(cursor)
      entry = lookup(build_candidates(cursor))
      entry&.version
    end

    # Returns the override signature string for a cursor, or nil if not overridden.
    def override(cursor)
      entry = lookup(build_candidates(cursor))
      entry&.signature
    end

    def has_versions?
      @exact.any? { |_, entry| entry.version } || @regex.any? { |_, entry| entry.version }
    end

    private

    # Normalize type signatures so that whitespace differences don't prevent matching.
    # Clang spells types like "const int *" (space before *) but users may write "const int*".
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
    # spelling (e.g., "DataType") appears both as namespace and method name.
    def sub_last(str, target, replacement)
      i = str.rindex(target)
      return str unless i
      str[0...i] + replacement + str[(i + target.length)..]
    end

    def normalize_signature(str)
      str
        .gsub(/\s+/, ' ')
        .gsub(/\s*\*/, '*')
        .gsub(/\s*&/, '&')
        .strip
    end

    def add_parameter_candidates(candidates, cursor, qualified_names)
      parameter_lists = []

      parameter_lists << (0...cursor.type.args_size).map { |i| cursor.type.arg_type(i).spelling }.join(", ")
      parameter_lists << (0...cursor.type.args_size).map { |i| cursor.type.arg_type(i).fully_qualified_name(cursor.printing_policy) }.join(", ")
      parameter_lists << (0...cursor.type.args_size).map { |i| cursor.type.arg_type(i).canonical.spelling }.join(", ")

      parameter_lists.uniq.each do |param_types|
        candidates << "#{cursor.spelling}(#{param_types})" unless candidates.include?("#{cursor.spelling}(#{param_types})")
        qualified_names.each do |qn|
          candidate = "#{qn}(#{param_types})"
          candidates << candidate unless candidates.include?(candidate)
        end
      end
    end

    # Rebuild a template specialization display name using cursor template
    # arguments. Type args are fully qualified semantically, while written
    # display text is preserved for integral or other non-type args that
    # libclang does not expose as names.
    #
    # Examples:
    #   `Holder<Tag, 7>`
    # becomes
    #   `Holder<Outer::Tag, 7>`
    #
    #   `takeValue<>()`
    # becomes
    #   `takeValue<7>()`
    def specialized_template_display_name(cursor, display)
      args = template_argument_display_values(cursor, display)
      return nil if args.nil? || args.empty? || args.any?(&:nil?)

      sub_template_args(display, "<#{args.join(', ')}>")
    end

    def template_argument_display_values(cursor, display)
      n = cursor.num_template_arguments
      return nil unless n > 0

      written_args = template_argument_texts(display)
      (0...n).map do |index|
        case cursor.template_argument_kind(index)
        when :template_argument_type
          cursor.template_argument_type(index).fully_qualified_name(cursor.printing_policy)
        when :template_argument_integral
          written_args[index] || cursor.template_argument_value(index).to_s
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

    def add_entry(name, skip: false, version: nil, signature: nil)
      return if name.nil?
      if name.start_with?('/') && name.end_with?('/') && name.length > 2
        @regex << [Regexp.new(name[1..-2]), SymbolEntry.new(skip: skip, version: version, signature: signature)]
      else
        key = normalize_signature(name)
        existing = @exact[key]
        if existing
          existing.merge(skip: skip, version: version, signature: signature)
        else
          @exact[key] = SymbolEntry.new(skip: skip, version: version, signature: signature)
        end
      end
    end
  end
end
