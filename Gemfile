source 'https://rubygems.org'

gemspec

if RUBY_PLATFORM =~ /linux/ && File.exist?('/mnt/c')
  gem "ffi-clang", path: "/mnt/c/Source/ffi-clang"  # WSL
else
  gem "ffi-clang", path: "c:/Source/ffi-clang"      # Windows
end
#gem "ffi-clang", github: "ioquatix/ffi-clang"
