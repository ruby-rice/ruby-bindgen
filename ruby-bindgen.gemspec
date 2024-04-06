# -*- encoding: utf-8 -*-

require_relative "lib/ruby-bindgen/version"

Gem::Specification.new do |spec|
  spec.name = "ruby-bindgen"
  spec.version = RubyBindgen::VERSION
  spec.homepage = "https://github.com/ruby-prof/ruby-prof/"
  spec.summary = "C and C++ binding generator for Ruby"
  spec.license = 'BSD-2-Clause'

  spec.metadata = {
    "bug_tracker_uri"   => "https://github.com/ruby-prof/ruby-prof/issues",
    "changelog_uri"     => "https://github.com/ruby-prof/ruby-prof/blob/master/CHANGES",
    "documentation_uri" => "https://ruby-prof.github.io/",
    "source_code_uri"   => "https://github.com/ruby-prof/ruby-prof/tree/v#{spec.version}",
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
                   'lib/ruby-bindgen/*.rb',
]

  spec.test_files = Dir["test/test_*.rb"]
  spec.required_ruby_version = '>= 2.7.0'
  spec.date = Time.now.strftime('%Y-%m-%d')
  spec.homepage = 'https://github.com/ruby-prof/ruby-prof'

  #spec.add_dependency('ffi-clang')
  spec.add_development_dependency('minitest')
end
