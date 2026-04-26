module RubyBindgen
  # Skip / version-guard / FFI-override decisions for cursors, looked up by
  # name strings supplied in the YAML symbols config.
  #
  # Owns the storage (an exact-match hash plus a list of regex entries) and
  # the policy queries (skip?, version, override). Delegates name
  # enumeration to SymbolCandidates so the matching logic is shared with
  # Namer / NameMapper.
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

    # Look up a cursor by trying each of its candidate names.
    # Returns a SymbolEntry or nil.
    def lookup_cursor(cursor)
      symbol_candidates = SymbolCandidates.new(cursor)
      lookup(symbol_candidates)
    end

    # Look up a list of pre-built candidate names.
    # Returns a SymbolEntry or nil.
    def lookup(candidates)
      candidates.each do |name|
        result = @exact[SymbolCandidates.normalize_signature(name)]
        return result if result
      end

      @regex.each do |pattern, entry|
        candidates.each do |name|
          return entry if pattern.match?(SymbolCandidates.normalize_signature(name))
        end
      end
      nil
    end

    # Check if a cursor should be skipped based on symbols config.
    def skip?(cursor)
      entry = lookup_cursor(cursor)
      entry&.skip? || false
    end

    # Check if a type spelling matches any skip symbol using word boundaries.
    # Used as a fallback for dependent/unexposed types where no declaration
    # is available.
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
      entry = lookup_cursor(cursor)
      entry&.version
    end

    # Returns the override signature string for a cursor, or nil if not overridden.
    def override(cursor)
      entry = lookup_cursor(cursor)
      entry&.signature
    end

    def has_versions?
      @exact.any? { |_, entry| entry.version } || @regex.any? { |_, entry| entry.version }
    end

    private

    def add_entry(name, skip: false, version: nil, signature: nil)
      return if name.nil?
      if name.start_with?('/') && name.end_with?('/') && name.length > 2
        @regex << [Regexp.new(name[1..-2]), SymbolEntry.new(skip: skip, version: version, signature: signature)]
      else
        key = SymbolCandidates.normalize_signature(name)
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
