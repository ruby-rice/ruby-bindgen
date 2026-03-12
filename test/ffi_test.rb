# encoding: UTF-8

require_relative './abstract_test'

class FfiTest < AbstractTest
  def test_forward_declarations
    run_ffi_test("forward.h", project: "forward",
      library_names: ["forward"], library_versions: [])
  end

  def test_structs
    run_ffi_test("structs.h", project: "structs",
      library_names: ["structs"], library_versions: [])
  end

  def test_clang
    run_ffi_test("clang-c/index.h", project: "clang",
      library_names: ["clang"], library_versions: [])
  end

  def test_proj
    run_ffi_test(["proj.h", "proj_experimental.h"], project: "proj",
      library_names: ["proj"], library_versions: [], module: "Proj::Api", version_check: "proj_version", library_search_path: "PROJ_LIB_PATH",
      symbols: { skip: ["PJ_INFO", "proj_info"],
                 versions: { 60100 => ["proj_normalize_for_visualization"],
                             60200 => ["proj_cleanup"],
                             80000 => ["proj_context_errno_string"] },
                 overrides: { "proj_is_crs" => "[:pointer], :bool" } })
  end

  def test_sqlite3
    run_ffi_test("sqlite3.h", project: "sqlite3",
      library_names: ["sqlite3"], library_versions: [])
  end

  def test_version_guards
    run_ffi_test("version_guards.h", project: "version_guards",
      library_names: ["version_guards"], library_versions: [], version_check: "version_guards_version",
      symbols: { versions: { 20000 => ["newFunction", "NewStruct", "NewEnum", "NewTypedef", "overriddenFunction",
                                       "MixedStruct::versioned_field", "MIXED_B"],
                              30000 => ["futureFunction", "MixedStruct::future_field", "MIXED_C"] },
                 overrides: { "overriddenFunction" => "[:int, :int, :int], :bool" } })
  end

  def test_constants
    run_ffi_test("constants.h", project: "constants",
      library_names: ["constants"], library_versions: [])
  end

  def test_unions
    run_ffi_test("unions.h", project: "unions",
      library_names: ["unions"], library_versions: [])
  end

  def test_filtering
    run_ffi_test("filtering.h", project: "filtering",
      library_names: ["filtering"], library_versions: [],
      export_macros: ["MY_EXPORT"],
      symbols: { skip: ["skippedFunction",
                        "alsoSkipped",
                        "/internal_helper.*/",
                        "SkippedStruct",
                        "SkippedEnum",
                        "SkippedTypedef",
                        "SkippedEmbedded"] })
  end

  def test_linkage_spec
    run_ffi_test("linkage_spec.h", project: "linkage_spec",
      library_names: ["linkage_spec"], library_versions: [],
      clang_args: ["-xc++"])
  end

  def test_rename
    run_ffi_test("rename.h", project: "rename",
      library_names: ["rename"], library_versions: [],
      symbols: {
        rename_types: [
          { "from" => "MY_3D_POINT", "to" => "My3DPoint" },
          { "from" => "ELLIPSOIDAL_CS_2D_TYPE", "to" => "EllipsoidalCs2DType" }
        ],
        rename_methods: [
          { "from" => "create_ellipsoidal_2D_cs", "to" => "create_cs" }
        ]
      })
  end

  private

  def run_ffi_test(match, **overrides)
    config_dir = File.join(__dir__, "headers", "c")
    config = load_config(config_dir)
    config[:match] = Array(match)
    overrides.each { |key, value| config[key] = value }

    inputter = RubyBindgen::Inputter.new(config_dir, config[:match])
    outputter = create_outputter("c")
    generator = RubyBindgen::Generators::FFI.new(inputter, outputter, config)
    generator.generate
    validate_result(generator.outputter)
  end
end
