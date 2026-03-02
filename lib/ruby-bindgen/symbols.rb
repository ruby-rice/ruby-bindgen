module RubyBindgen
  class Symbols
    def initialize(config = {})
      @exact = {}
      @regex = []

      (config[:skip] || []).each do |name|
        add_entry(name, action: :skip, version: nil)
      end

      (config[:versions] || {}).each do |version, names|
        names.each do |name|
          add_entry(name, action: :version, version: version)
        end
      end

      (config[:overrides] || {}).each do |name, signature|
        add_entry(name.to_s, action: :override, version: nil, signature: signature)
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

      candidates = [cursor.spelling, qualified_name]

      # Add display_name-based candidates for template specializations
      # (display_name includes template args, e.g., "DataType<hfloat>" or "saturate_cast<hfloat>(uchar)")
      display = cursor.display_name
      if display != cursor.spelling
        qualified_display = qualified_name.sub(cursor.spelling, display)
        candidates << display << qualified_display

        # Also add candidates with fully-qualified template args.
        # display_name uses unqualified args (e.g., "DataType<hfloat>") but users
        # may configure symbols with qualified args (e.g., "cv::DataType<cv::hfloat>").
        # Use clang's template_argument_type API to get the qualified arg spellings.
        if cursor.type.respond_to?(:num_template_arguments)
          n = cursor.type.num_template_arguments
          if n > 0
            qualified_args = (0...n).map { |i| cursor.type.template_argument_type(i).spelling }
            qualified_args_str = "<#{qualified_args.join(', ')}>"
            fq_display = display.sub(/<[^>]+>/, qualified_args_str)
            if fq_display != display
              fq_qualified_display = qualified_name.sub(cursor.spelling, fq_display)
              candidates << fq_display << fq_qualified_display
            end
          end
        end

        # Function template specializations: clang reports display_name with empty
        # template args (e.g., "saturate_cast<>(int)"). Reconstruct qualified args
        # from the type_ref children which reference the substituted types.
        if cursor.kind == :cursor_function && display.include?('<>')
          type_refs = []
          cursor.each(false) do |child, _|
            type_refs << child.type.spelling if child.kind == :cursor_type_ref
            next :continue
          end
          unless type_refs.empty?
            qualified_args_str = "<#{type_refs.join(', ')}>"
            fq_display = display.sub('<>', qualified_args_str)
            fq_qualified_display = qualified_name.sub(cursor.spelling, fq_display)
            candidates << fq_display << fq_qualified_display
          end
        end
      end

      if cursor.type.respond_to?(:args_size)
        param_types = (0...cursor.type.args_size).map { |i| cursor.type.arg_type(i).spelling }.join(", ")
        candidates << "#{cursor.spelling}(#{param_types})"
        candidates << "#{qualified_name}(#{param_types})"
      end
      candidates
    end

    # Look up a symbol by trying each candidate in order.
    # Returns the value hash ({action: :skip, ...}) or nil.
    def lookup(candidates)
      candidates.each do |name|
        result = @exact[name]
        return result if result
      end

      @regex.each do |pattern, value|
        candidates.each do |name|
          return value if pattern.match?(name)
        end
      end
      nil
    end

    # Iterate over exact (non-regex) skip symbol keys.
    def each(&block)
      @exact.each do |key, value|
        yield key if value[:action] == :skip
      end
    end

    # Check if a cursor should be skipped based on symbols config.
    def skip?(cursor)
      result = lookup(build_candidates(cursor))
      result && result[:action] == :skip
    end

    # Returns the version guard value for a cursor, or nil if not version-guarded.
    def version(cursor)
      result = lookup(build_candidates(cursor))
      result[:version] if result && result[:action] == :version
    end

    # Returns the override signature string for a cursor, or nil if not overridden.
    def override(cursor)
      result = lookup(build_candidates(cursor))
      result[:signature] if result && result[:action] == :override
    end

    private

    def add_entry(name, action:, version:, signature: nil)
      value = { action: action, version: version, signature: signature }
      if name.start_with?('/') && name.end_with?('/')
        @regex << [Regexp.new(name[1..-2]), value]
      else
        @exact[name] = value
      end
    end
  end
end
