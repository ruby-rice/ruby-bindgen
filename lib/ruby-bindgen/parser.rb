# frozen_string_literal: true

# Released under the MIT License.

module RubyBindgen
  class Parser
    attr_reader :translation_unit

    def initialize(path, args)
      index = FFI::Clang::Index.new(false, true)
      @translation_unit = index.parse_translation_unit(path, args, [],
                                                       [:skip_function_bodies, :keep_going])
    end

    def build_tree
      @translation_unit.cursor.visit_children do |cursor, parent_cursor|
        #unless cursor.location.from_main_file?
        #  next :recurse
        #end
        if cursor.location.in_system_header?
          next :continue
        end

        if @skip.include?(parent_cursor.kind) || @skip.include?(cursor.kind)
          next :continue
        end

        klass = Nodes::Registry.instance.get(parent_cursor.kind)
        if klass
          parent = tree[parent_cursor] ||= klass.from_cursor(parent_cursor)
        else
          puts "Skipping #{parent_cursor.kind} #{parent_cursor.spelling} #{parent_cursor.location.file}:#{parent_cursor.location.line}"
        end

        klass = Nodes::Registry.instance.get(cursor.kind)
        if klass
          child = tree[cursor] ||= klass.from_cursor(cursor, parent)
        else
          puts "Skipping #{cursor.kind} #{cursor.spelling} #{cursor.location.file}:#{cursor.location.line}"
        end

        next :recurse
      end

      root
    end
  end
end