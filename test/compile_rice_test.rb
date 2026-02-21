# encoding: UTF-8

require_relative './abstract_test'
require 'open3'

class CompileRiceTest < AbstractTest
  VS_INSTALLATIONS = [
    'C:/Program Files/Microsoft Visual Studio/18/Insiders',
    'C:/Program Files/Microsoft Visual Studio/2022/Enterprise',
    'C:/Program Files/Microsoft Visual Studio/2022/Professional',
    'C:/Program Files/Microsoft Visual Studio/2022/Community',
  ].freeze

  VCVARS_SUBPATH = 'VC/Auxiliary/Build/vcvars64.bat'
  CMAKE_SUBPATH = 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'

  def test_compile_bindings
    bindings_dir = File.join(__dir__, 'bindings', 'cpp')
    preset = determine_preset

    Dir.chdir(bindings_dir) do
      # Configure with no-op linker (compile-only, skip linking)
      noop_linker = msvc? ? "cmd /c exit 0" : ":"
      output, success = run_cmake("--preset", preset,
                                  "-DCMAKE_CXX_CREATE_SHARED_MODULE=#{noop_linker}",
                                  "-DCMAKE_CXX_CREATE_SHARED_LIBRARY=#{noop_linker}")
      flunk "CMake configure failed:\n#{output}" unless success

      # Build (compiles only, linking is a no-op)
      output, success = run_cmake("--build", "build/#{preset}")
      flunk "CMake build failed:\n#{output}" unless success
    end

    pass
  end

  private

  def run_cmake(*args)
    if msvc?
      run_cmake_msvc(*args)
    else
      output, status = Open3.capture2e("cmake", *args)
      [output, status.success?]
    end
  end

  def run_cmake_msvc(*args)
    vs_path = VS_INSTALLATIONS.find { |path| File.directory?(path) }

    if vs_path
      vcvars = File.join(vs_path, VCVARS_SUBPATH)
      cmake = File.join(vs_path, CMAKE_SUBPATH)
    else
      vcvars = nil
      cmake = "cmake"
    end

    cmd_args = args.map { |arg| arg.include?(' ') ? "\"#{arg}\"" : arg }.join(' ')

    if vcvars
      # Must pass entire command as single string for cmd /c to work correctly
      full_cmd = "cmd /c \"\"#{vcvars}\" >nul 2>&1 && \"#{cmake}\" #{cmd_args}\""
      output, status = Open3.capture2e(full_cmd)
    else
      output, status = Open3.capture2e(cmake, *args)
    end

    [output, status.success?]
  end

  def msvc?
    RbConfig::CONFIG['arch'] =~ /mswin/
  end

  def determine_preset
    case RbConfig::CONFIG['arch']
    when /mswin/
      'msvc-debug'
    when /mingw/
      'mingw-debug'
    when /darwin/
      'macos-debug'
    else
      'linux-debug'
    end
  end
end
