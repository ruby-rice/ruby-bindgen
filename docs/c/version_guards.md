# Version Detection

When `symbols.versions` has entries, `ruby-bindgen` generates version-guarded Ruby conditionals and a `{project}_version.rb` skeleton file. The user implements the version detection method in that file — typically by calling the library's own version API.

## Configuration

This example is from [proj4rb](https://github.com/cfis/proj4rb), Ruby bindings for the [PROJ](https://proj.org/) coordinate transformation library. PROJ's API has grown significantly across versions — `proj_normalize_for_visualization` was added in 6.1.0, `proj_cleanup` in 6.2.0, and so on.

```yaml
format: FFI
project: proj
module: Proj::Api

library_names:
  - proj

symbols:
  skip:
    - PJ_INFO       # manually defined in version file
    - proj_info      # manually defined in version file

  versions:
    # 6.1.0
    60100:
      - proj_normalize_for_visualization

    # 6.2.0
    60200:
      - proj_cleanup
      - proj_as_projjson
      - proj_create_crs_to_crs_from_pj

    # 8.0.0
    80000:
      - proj_context_errno_string
```

The version file calls `proj_info()` and uses `PJ_INFO` to compute the runtime version number. Since those symbols are manually defined in the version file, add them to `skip` so they aren't also generated in the content files.

## Generated Output

The generator produces three things:

**1. Version guards in content files** — version-specific symbols are wrapped in conditionals:

```ruby
if proj_version >= 60100
  attach_function :proj_normalize_for_visualization, ...
end
if proj_version >= 60200
  attach_function :proj_cleanup, :proj_cleanup, [], :void
end
```

**2. Version require in the project file** (`proj_ffi.rb`):

```ruby
require_relative 'proj_version'
require_relative './proj'
```

**3. Version skeleton file** (`proj_version.rb`) — generated once, then user-maintained:

```ruby
module Proj
  module Api
    def self.proj_version
      # Return the runtime library version as an integer.
      # Example: 90602 for version 9.6.2
      raise NotImplementedError, "Implement proj_version to return the runtime library version number"
    end
  end
end
```

## Implementing Version Detection

Replace the skeleton with your library's version API. PROJ provides `proj_info()` which returns a `PJ_INFO` struct with `major`, `minor`, and `patch` fields. Since the version file is loaded before the generated content files, define the struct and function here:

```ruby
module Proj
  module Api
    class PjInfo < FFI::Struct
      layout :major, :int,
             :minor, :int,
             :patch, :int,
             :release, :string,
             :version, :string,
             :searchpath, :string,
             :paths, :pointer,
             :path_count, :ulong
    end

    attach_function :proj_info, :proj_info, [], PjInfo.by_value

    def self.proj_version
      info = proj_info
      info[:major] * 10000 + info[:minor] * 100 + info[:patch]
    end
  end
end
```

The version file is loaded before the content files, so `proj_version` is available when the guards execute. The skeleton is only generated if the file doesn't already exist — your implementation is preserved across re-runs.
