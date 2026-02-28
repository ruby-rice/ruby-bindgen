module RubyBindgen
  class Symbols
    def initialize(entries = [])
      @exact = {}
      @regex = []
      entries.each do |entry|
        key = entry["name"]
        value = { action: entry["action"]&.to_sym }
        if key.start_with?('/') && key.end_with?('/')
          @regex << [Regexp.new(key[1..-2]), value]
        else
          @exact[key] = value
        end
      end
    end

    # Build candidate names for a cursor for symbol lookup.
    # Returns [simple_name, qualified_name, simple_with_params, qualified_with_params].
    def build_candidates(cursor)
      qualified_name = cursor.spelling
      parent = cursor.semantic_parent
      while parent && !parent.kind.nil? && parent.kind != :cursor_translation_unit
        qualified_name = "#{parent.spelling}::#{qualified_name}" if parent.spelling && !parent.spelling.empty?
        parent = parent.semantic_parent
      end

      candidates = [cursor.spelling, qualified_name]
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
  end
end
