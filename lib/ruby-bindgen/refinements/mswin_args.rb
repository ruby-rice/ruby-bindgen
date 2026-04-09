# Compat patch for ffi-clang < 0.15.1 on MSVC.
# Uses -isystem instead of -I for auto-discovered system includes so
# that clang treats them as system headers (in_system_header? returns true).
# Without this, the generator processes STL internals like xstring.
#
# Remove once ffi-clang >= 0.15.1 is released.

if defined?(FFI::Clang::MswinArgs)
  module FFI
    module Clang
      class MswinArgs < Args
        private

        def extra_args(command_line_args)
          args = []

          system_includes.each do |path|
            unless command_line_args.include?(path)
              args.push("-isystem", path)
            end
          end

          args
        end
      end
    end
  end
end
