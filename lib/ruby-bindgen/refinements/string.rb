class String
  # Taken from ActiveSupport with modifications
  def upcase_first
    if self.length > 0
      self[0].upcase.concat(self[1..-1])
    else
      self
    end
  end

  # Taken from ActiveSupport with modifications
  def camelize()
    if self.match?(/\A[a-z\d]*\z/)
      return self.capitalize
    end

    if self.match?(/\A[A-Z_0-9]*\z/)
      return self
    end

    string = self.sub(/^[a-z\d]*/) { |match| match.capitalize! || match }
    string.gsub!(/\/, ::/)
    string.gsub!(/(?:_|-|\.|::|,| |\<|\>|(\/))([a-z\d]*)/i) do
      word = $2
      word[0] = word[0].capitalize || word[0] unless word.empty?
      $1 ? "::#{word}" : word
    end
    string
  end

  # Taken from ActiveSupport with modifications
  def underscore
    return self unless /[A-Z-]|::/.match?(self)
    word = self.gsub("::".freeze, "/".freeze)
    word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2'.freeze)
    word.gsub!(/([a-z])([A-Z])/, '\1_\2'.freeze)
    word.gsub!(/([a-z])(\d+[A-Z])/, '\1_\2'.freeze)
    word.tr!("-".freeze, "_".freeze)
    word.downcase!
    word
  end
end