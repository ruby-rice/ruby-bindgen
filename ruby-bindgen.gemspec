# -*- encoding: utf-8 -*-

require_relative "lib/ruby-bindgen/version"

Gem::Specification.new do |spec|
  spec.name = "ruby-bindgen"
  spec.version = RubyBindgen::VERSION
  spec.homepage = "https://github.com/ruby-rice/ruby-bindgen/"
  spec.summary = "C and C++ binding generator for Ruby"
  spec.license = 'BSD-2-Clause'

  spec.metadata = {
    "bug_tracker_uri"   => "https://github.com/ruby-rice/ruby-bindgen/issues",
    "changelog_uri"     => "https://github.com/ruby-rice/ruby-bindgen/blob/main/CHANGES",
    "source_code_uri"   => "https://github.com/ruby-rice/ruby-bindgen/tree/v#{spec.version}",
  }

  spec.author = "Charlie Savage"
  spec.platform = Gem::Platform::RUBY
  spec.require_path = "lib"
  spec.bindir = "bin"
  spec.executables = ["ruby-bindgen"]
  spec.files = Dir['CHANGES',
                   'LICENSE',
                   'Rakefile',
                   'README.md',
                   'ruby-bindgen.gemspec',
                   'bin/ruby-bindgen',
                   'doc/**/*',
                   'lib/**/*',
]

  spec.test_files = Dir["test/test_*.rb"]
  spec.required_ruby_version = '>= 3.2.0'
  spec.date = Time.now.strftime('%Y-%m-%d')
  spec.homepage = 'https://github.com/ruby-rice/ruby-bindgen'

  spec.add_dependency 'ffi', '>= 1.16'
  spec.add_dependency 'ffi-clang', '>= 0.14'

  spec.add_development_dependency 'logger'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'mutex_m'
  spec.add_development_dependency 'rake'
end
