module Forward

  class F < FFI::Struct
    layout :b, :pointer,
           :c, :pointer
  end

  class B < FFI::Struct
    layout :bname, :pointer
  end

  class C < FFI::Struct
    layout :cname, :pointer
  end

  typedef :pointer, :Opaque
  attach_function :use_opaque, :use_opaque, [:pointer], :void
  attach_function :create_opaque, :create_opaque, [], :pointer
end
