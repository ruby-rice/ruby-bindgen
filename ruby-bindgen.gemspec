# -*- encoding: utf-8 -*-

require_relative "lib/ruby-bindgen/version"

Gem::Specification.new do |spec|
  spec.name = "ruby-bindgen"
  spec.version = RubyBindgen::VERSION
  spec.homepage = "https://github.com/ruby-rice/ruby-bindgen/"
  spec.summary = "C and C++ binding generator for Ruby"
  spec.description = <<~DESC
    ruby-bindgen reads C and C++ headers with libclang and emits Ruby bindings.
    It supports three output formats: Rice C++ source for high-fidelity C++ wrappers,
    raw FFI for plain C libraries, and CMake build files to compile the generated
    extensions. Bindings are driven from a YAML configuration that controls header
    matching, symbol filtering, name mapping, and version guards. Battle-tested
    against OpenCV (thousands of classes) and PROJ.
  DESC
  spec.license = 'BSD-2-Clause'

  spec.metadata = {
    "bug_tracker_uri"   => "https://github.com/ruby-rice/ruby-bindgen/issues",
    "changelog_uri"     => "https://github.com/ruby-rice/ruby-bindgen/blob/main/CHANGELOG.md",
    "source_code_uri"   => "https://github.com/ruby-rice/ruby-bindgen/tree/v#{spec.version}",
  }

  spec.author = "Charlie Savage"
  spec.platform = Gem::Platform::RUBY
  spec.require_path = "lib"
  spec.bindir = "bin"
  spec.executables = ["ruby-bindgen"]
  spec.files = Dir['CHANGELOG.md',
                   'LICENSE',
                   'Rakefile',
                   'README.md',
                   'ruby-bindgen.gemspec',
                   'bin/ruby-bindgen',
                   'docs/**/*',
                   'lib/**/*',
]

  spec.test_files = Dir["test/*_test.rb"]
  spec.required_ruby_version = '>= 3.2.0'

  spec.add_dependency 'ffi', '>= 1.16'
  spec.add_dependency 'ffi-clang', '>= 0.16.0'

  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-cobertura'
end
