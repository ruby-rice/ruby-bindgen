# encoding: UTF-8

require 'tmpdir'
require 'fileutils'

require_relative './abstract_test'

class RiceAbstractTest < AbstractTest
  ParsedUnit = Struct.new(:dir, :parser, :translation_unit, :path)

  class TranslationUnitCapture
    attr_reader :translation_unit

    def visit_start
    end

    def visit_translation_unit(translation_unit, _path, _relative_path)
      @translation_unit = translation_unit
    end

    def visit_end
    end
  end

  def setup
    @parsed_units = []
  end

  def teardown
    @parsed_units.each do |parsed|
      FileUtils.remove_entry(parsed.dir) if parsed.dir && Dir.exist?(parsed.dir)
    end
  end

  private

  def parse_cpp(source)
    dir = Dir.mktmpdir("rice-components")
    path = File.join(dir, "fixture.hpp")
    File.write(path, source)

    config = load_config(File.join(__dir__, "headers", "cpp"))
    inputter = RubyBindgen::Inputter.new(dir, ["fixture.hpp"])
    parser = RubyBindgen::Parser.new(inputter, config[:clang_args], libclang: config[:libclang])
    capture = TranslationUnitCapture.new
    capture_io { parser.generate(capture) }

    parsed = ParsedUnit.new(dir, parser, capture.translation_unit, path)
    @parsed_units << parsed

    [parsed, build_collaborators(parsed, config)]
  end

  def build_collaborators(parsed, config)
    rename_types = RubyBindgen::NameMapper.from_config((config[:symbols] || {})[:rename_types] || [])
    rename_methods = RubyBindgen::Generators::Rice::OPERATOR_MAPPINGS.merge(
      RubyBindgen::NameMapper.from_config((config[:symbols] || {})[:rename_methods] || [])
    )
    namer = RubyBindgen::Namer.new(rename_types, rename_methods,
                                   RubyBindgen::Generators::Rice::CONVERSION_TYPE_MAPPINGS)
    FFI::Clang::Cursor.namer = namer

    type_index = RubyBindgen::Generators::TypeIndex.new
    type_index.build!(parsed.translation_unit.cursor)

    reference_qualifier = RubyBindgen::Generators::ReferenceQualifier.new
    type_speller = RubyBindgen::Generators::TypeSpeller.new(type_index: type_index)
    type_speller.printing_policy = parsed.translation_unit.cursor.printing_policy

    inputter = RubyBindgen::Inputter.new(parsed.dir, ["fixture.hpp"])
    rice = RubyBindgen::Generators::Rice.new(inputter, create_outputter("cpp"), config)

    {
      reference_qualifier: reference_qualifier,
      signature_builder: RubyBindgen::Generators::SignatureBuilder.new(
        type_speller: type_speller,
        reference_qualifier: reference_qualifier,
        cursor_literals: RubyBindgen::Generators::Rice::CURSOR_LITERALS,
        fundamental_types: RubyBindgen::Generators::Rice::FUNDAMENTAL_TYPES
      ),
      template_resolver: RubyBindgen::Generators::TemplateResolver.new(
        reference_qualifier: reference_qualifier,
        type_speller: type_speller,
        namer: namer
      ),
      type_index: type_index,
      type_speller: type_speller
    }
  end

  def find_cursor(root, kind, spelling)
    cursor = root.find_by_kind(true, kind).find { |child| child.spelling == spelling }
    refute_nil cursor, "Expected to find #{kind} #{spelling}"
    cursor
  end

  def find_default_expression(param)
    default_value_kinds = [:cursor_unexposed_expr, :cursor_call_expr, :cursor_decl_ref_expr,
                           :cursor_c_style_cast_expr, :cursor_cxx_static_cast_expr,
                           :cursor_cxx_functional_cast_expr, :cursor_cxx_typeid_expr,
                           :cursor_paren_expr] + RubyBindgen::Generators::Rice::CURSOR_LITERALS
    param.find_by_kind(false, *default_value_kinds).find do |expr|
      if expr.kind == :cursor_decl_ref_expr
        ref = expr.referenced
        ref && ref.kind != :cursor_non_type_template_parameter && ref.kind != :cursor_template_type_parameter
      else
        true
      end
    end
  end
end
