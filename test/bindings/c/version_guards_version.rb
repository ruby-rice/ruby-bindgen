module VersionGuards
  def self.version_guards_version
    # Return the runtime library version as an integer.
    # Example: 90602 for version 9.6.2
    raise NotImplementedError, "Implement version_guards_version to return the runtime library version number"
  end
end
