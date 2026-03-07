module RubyBindgen
  class SymbolEntry
    attr_reader :version, :signature

    def initialize(skip: false, version: nil, signature: nil)
      @skip = skip
      @version = version
      @signature = signature
    end

    def skip?
      @skip
    end

    def merge(skip: false, version: nil, signature: nil)
      @skip = true if skip
      @version = version if version
      @signature = signature if signature
    end
  end
end
