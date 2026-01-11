# encoding: UTF-8

require_relative './abstract_test'

class RiceTest < AbstractTest
  def test_classes
    header = "cpp/classes.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_enums
    header = "cpp/enums.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_functions
    header = "cpp/functions.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_inheritance
    header = "cpp/inheritance.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_template
    header = "cpp/templates.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_constructors
    header = "cpp/constructors.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_operators
    header = "cpp/operators.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_default_values
    header = "cpp/default_values.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_iterators
    header = "cpp/iterators.hpp"
    # Need system includes to parse std::vector
    if RUBY_PLATFORM =~ /mingw|mswin|cygwin/
      args = [
        "-IC:/Program Files/Microsoft Visual Studio/18/Insiders/VC/Tools/MSVC/14.44.35207/include",
        "-IC:/Program Files (x86)/Windows Kits/10/Include/10.0.26100.0/ucrt",
        "-IC:/Program Files/Microsoft Visual Studio/18/Insiders/VC/Tools/Llvm/lib/clang/20/include",
        "-xc++"
      ]
    else
      # Linux/WSL - need to explicitly set clang resource dir for libclang
      clang_version = `clang --version`[/clang version (\d+)/, 1]
      args = [
        "-I/usr/lib/clang/#{clang_version}/include",
        "-xc++"
      ]
    end
    parser = create_parser(header, args)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_template_inheritance
    header = "cpp/template_inheritance.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_overloads
    header = "cpp/overloads.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_incomplete_types
    header = "cpp/incomplete_types.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header)
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end

  def test_filtering
    header = "cpp/filtering.hpp"
    parser = create_parser(header)
    visitor = create_visitor(RubyBindgen::Visitors::Rice, header,
                             export_macros: ["MY_EXPORT"],
                             skip_symbols: ["skippedByName", "alsoSkippedByName", "skippedMethod", "SkippedClass"])
    parser.generate(visitor)
    validate_result(visitor.outputter)
  end
end
