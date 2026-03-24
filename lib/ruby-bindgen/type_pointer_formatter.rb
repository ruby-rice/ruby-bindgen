module RubyBindgen
  # Shared pointer-type formatting for both the fully-qualified-name shim and
  # the Rice type speller. The caller supplies how non-pointer child types
  # should be spelled.
  module TypePointerFormatter
    module_function

    def pointer_spelling(type)
      pointee = type.pointee

      if function_pointer_pointee?(pointee)
        ptr_const = type.const_qualified? ? " const" : ""
        result_type = yield(pointee.result_type)
        arg_types = pointee.arg_types.map { |arg_type| yield(arg_type) }.join(", ")
        return "#{result_type} (*#{ptr_const})(#{arg_types})"
      end

      parts = []
      current = type
      while current.kind == :type_pointer
        inner = current.pointee
        break if function_pointer_pointee?(inner)

        parts << (current.const_qualified? ? "*const" : "*")
        current = inner
      end

      "#{yield(current)} #{parts.reverse.join}"
    end

    def function_pointer_pointee?(type)
      type.kind == :type_function_proto || type.kind == :type_function_no_proto
    end
  end
end
