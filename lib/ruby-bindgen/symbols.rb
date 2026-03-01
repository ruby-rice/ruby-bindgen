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

    # Iterate over exact (non-regex) symbol keys.
    def each(&block)
      @exact.each_key(&block)
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

    private

    def add_entry(name, action:, version:)
      value = { action: action, version: version }
      if name.start_with?('/') && name.end_with?('/')
        @regex << [Regexp.new(name[1..-2]), value]
      else
        @exact[name] = value
      end
    end
  end
end
