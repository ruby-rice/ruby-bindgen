module FFI
  module Clang
    class SourceRange
      # Monkey patch to fix crash when clang fails to correctly parse a file.
      # See https://github.com/ioquatix/ffi-clang/pull/99
      def text
        file_path = self.start.file
        return nil if file_path.nil?

        ::File.open(file_path, "r") do |file|
          file.seek(self.start.offset)
          return file.read(self.bytesize)
        end
      end
    end
  end
end
