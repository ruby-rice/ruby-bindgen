module Filtering
  attach_function :exported_function, :exportedFunction, [:int], :int
  attach_function :another_exported, :anotherExported, [:double, :double], :double

  class IncludedStruct < FFI::Struct
    layout :x, :int,
           :y, :int
  end

  IncludedEnum = enum(
    :VALUE_ONE, 0,
    :VALUE_TWO, 1
  )

  typedef :int, :included_typedef
end
