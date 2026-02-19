# encoding: UTF-8

require_relative './abstract_test'

class FfiTest < AbstractTest
  def test_forward_declarations
    header = "c/forward.h"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::FFI, header, nil,
                             library_names: ["forward"], library_versions: [])
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_structs
    header = "c/structs.h"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::FFI, header, nil,
                             library_names: ["structs"], library_versions: [])
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_clang
    header = "c/clang-c/index.h"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::FFI, header, nil,
                             library_names: ["clang"], library_versions: [])
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_proj
    header = "c/proj.h"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::FFI, header, nil,
                             library_names: ["proj"], library_versions: [])
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_sqlite3
    header = "c/sqlite3.h"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::FFI, header, nil,
                             library_names: ["sqlite3"], library_versions: [])
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end
end
