if ENV['COVERAGE']
  require 'simplecov'
  if ENV['CI']
    require 'simplecov-cobertura'
    SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
  end
  SimpleCov.start do
    add_filter '/test/'
    track_files 'lib/**/*.rb'
  end
end
