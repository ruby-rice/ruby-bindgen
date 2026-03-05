module Unions

  class SimpleUnion < FFI::Union
    layout :i, :int,
           :d, :double
  end

  class InnerUnion < FFI::Union
    layout :x, :int,
           :y, :double
  end

  class OuterUnion < FFI::Union
    layout :inner, InnerUnion,
           :z, :long
  end

  class MixedData < FFI::Struct
    layout :a, :int,
           :b, :int
  end

  class MixedUnion < FFI::Union
    layout :data, MixedData,
           :raw, :long
  end
end
