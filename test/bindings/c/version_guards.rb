module VersionGuards
  TEST_VERSION = 25000
  attach_function :stable_function, :stableFunction, [:int], :int

  class StableStruct < FFI::Struct
    layout :x, :int,
           :y, :int
  end

  StableEnum = enum(
    :STABLE_A, 0,
    :STABLE_B, 1
  )

  typedef :int, :stable_typedef
  if TEST_VERSION >= 20000
    attach_function :new_function, :newFunction, [:double], :void

    class NewStruct < FFI::Struct
      layout :a, :int,
             :b, :int
    end

    NewEnum = enum(
      :NEW_A, 10,
      :NEW_B, 20
    )

    typedef :double, :new_typedef
  end
  if TEST_VERSION >= 30000
    attach_function :future_function, :futureFunction, [:int, :int], :int
  end
end
