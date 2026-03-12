module RubyBindgen
  class NameMapper
    attr_reader :exact, :regex
    protected :exact, :regex

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
      exact_mappings = @exact.merge(other.exact).map { |k, v| [k, v] }
      regex_mappings = other.regex + @regex
      self.class.new(exact_mappings + regex_mappings)
    end

  end
end
