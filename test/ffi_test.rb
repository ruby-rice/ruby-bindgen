# encoding: UTF-8

require_relative './abstract_test'

class FfiTest < AbstractTest
  # def test_forward_declarations
  #   headers_path = File.join(__dir__, "headers")
  #
  #   parser = parse_file('headers/forward.h', "-I#{headers_path}")
  #   visitor = RubyBindgen::Visitors::FFI.new(parser.translation_unit, library_names: ["clang"],
  #                                            library_versions: [])
  #   io = visitor.visit
  #   validate_result('ffi/forward.rb', io.string)
  # end

  def test_structs
    headers_path = File.join(__dir__, "headers")
    parser = parse_file('headers/structs.h', "-I#{headers_path}")
    visitor = RubyBindgen::Visitors::FFI.new(parser.translation_unit, library_names: [],
                                             library_versions: [])
    io = visitor.visit
    validate_result('ffi/structs.rb', io.string)
  end

  def test_clang
    headers_path = File.join(__dir__, "headers")

    parser = parse_file('headers/clang-c/index.h', "-I#{headers_path}")
    visitor = RubyBindgen::Visitors::FFI.new(parser.translation_unit, library_names: ["clang"],
                                              library_versions: [])
    io = visitor.visit
    validate_result('ffi/clang/clang.rb', io.string)
  end

  def test_proj
    parser = parse_file('headers/proj.h')
    visitor = RubyBindgen::Visitors::FFI.new(parser.translation_unit, library_names: ["proj"],
                                           library_versions: ["25"])
    io = visitor.visit

    validate_result('ffi/proj.rb', io.string)
  end

  def test_sqlite3
    parser = parse_file('headers/sqlite3.h')
    visitor = RubyBindgen::Visitors::FFI.new(parser.translation_unit, library_names: ["sqlite3"],
                                             library_versions: ["0"])
    io = visitor.visit

    validate_result('ffi/sqlite3.rb', io.string)
  end
end
