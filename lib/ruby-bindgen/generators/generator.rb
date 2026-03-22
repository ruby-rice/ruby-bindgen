require 'erb'

module RubyBindgen
  module Generators
    class Generator
      attr_reader :inputter, :outputter, :config

      def initialize(inputter, outputter, config)
        @inputter = inputter
        @outputter = outputter
        @config = config
        @project = config[:project]&.gsub(/-/, '_')
      end

      def project
        @project
      end

      def generate
        raise NotImplementedError
      end

      def render_template(template, local_variables = {})
        template_path = File.join(self.class.template_dir, "#{template}.erb")
        template_content = File.read(template_path)
        template = ERB.new(template_content, :trim_mode => '-')
        template.filename = template_path # This allows debase to stop at breakpoints in templates!
        b = self.binding
        local_variables.each do |key, value|
          b.local_variable_set(key, value)
        end
        template.result(b)
      end

      # Check whether a cursor originates from the translation unit's main file.
      # This intentionally uses libclang file-object equality rather than comparing
      # raw file-name strings. Cursor locations only expose the file path string,
      # so we resolve that path back through `translation_unit.file(...)` and let
      # libclang compare the resulting file objects.
      def translation_unit_file?(cursor)
        file_name = cursor.file_location.file
        translation_unit_file = cursor.translation_unit.file
        file = file_name && cursor.translation_unit.file(file_name)
        file && translation_unit_file && file == translation_unit_file
      end

      # Strip reference qualifiers, then follow pointer layers to the underlying
      # pointee type.
      #
      # Examples:
      #   `Container<Item>* const&`
      # becomes
      #   `Container<Item>`
      #
      #   `Skipped**`
      # becomes
      #   `Skipped`
      def unwrapped_indirection_type(type)
        type = type.non_reference_type if reference_type?(type)
        while type.kind == :type_pointer
          type = type.pointee
          type = type.non_reference_type if reference_type?(type)
        end
        type
      end

      def reference_type?(type)
        type.kind == :type_lvalue_ref || type.kind == :type_rvalue_ref
      end

      def self.template_dir
        raise NotImplementedError
      end
    end
  end
end
