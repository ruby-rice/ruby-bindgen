module RubyBindgen
  class NameMapper
    def initialize(mappings = [])
      @exact = {}
      @regex = []
      mappings.each do |pattern, replacement|
        if pattern.is_a?(Regexp)
          @regex << [pattern, replacement]
        else
          @exact[pattern] = replacement
        end
      end
    end

    def empty?
      @exact.empty? && @regex.empty?
    end

    # Factory: parses YAML config array of {from:, to:} entries
    def self.from_config(mappings)
      parsed = mappings.map do |entry|
        key = entry["from"]
        replacement = entry["to"]
        if key.start_with?('/') && key.end_with?('/')
          [Regexp.new(key[1..-2]), replacement]
        else
          [key, replacement]
        end
      end
      new(parsed)
    end

    # Factory: parses a YAML list (skip_symbols style) into match-only mappings
    def self.from_list(patterns)
      parsed = patterns.map do |pattern|
        if pattern.start_with?('/') && pattern.end_with?('/')
          [Regexp.new(pattern[1..-2]), true]
        else
          [pattern, true]
        end
      end
      new(parsed)
    end

    # Look up a name, trying each candidate in order.
    # Returns the replacement value or nil.
    def lookup(*candidates)
      # O(1) exact match
      candidates.each do |name|
        result = @exact[name]
        return result if result
      end

      # Regex fallback
      @regex.each do |pattern, replacement|
        candidates.each do |name|
          if (m = pattern.match(name))
            if replacement.is_a?(String)
              return replacement.gsub(/\\(\d+)/) { m[$1.to_i] }
            else
              return replacement
            end
          end
        end
      end
      nil
    end

    # Merge two tables. Other's entries override self's.
    def merge(other)
      merged = self.class.allocate
      merged.instance_variable_set(:@exact, @exact.merge(other.instance_variable_get(:@exact)))
      merged.instance_variable_set(:@regex, other.instance_variable_get(:@regex) + @regex)
      merged
    end

    # Returns true if any candidate matches (exact or regex).
    def match?(*candidates)
      !lookup(*candidates).nil?
    end

    # Iterate over exact (non-regex) keys.
    def each_exact_key(&block)
      @exact.each_key(&block)
    end
  end
end
