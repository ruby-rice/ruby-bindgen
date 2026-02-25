require 'erb'

module RubyBindgen
  module Generators
    class Generator
      attr_reader :inputter, :outputter, :config

      def initialize(inputter, outputter, config)
        @inputter = inputter
        @outputter = outputter
        @config = config
        @project = config[:extension]&.gsub(/-/, '_')
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

      def self.template_dir
        raise NotImplementedError
      end
    end
  end
end
