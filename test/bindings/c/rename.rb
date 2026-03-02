module Rename

  EllipsoidalCs2DType = enum(
    :CS_2D_LONGITUDE_LATITUDE, 0,
    :CS_2D_LATITUDE_LONGITUDE, 1
  )

  class My3DPoint < FFI::Struct
    layout :x, :double,
           :y, :double,
           :z, :double
  end

  attach_function :create_cs, :create_ellipsoidal_2D_cs, [EllipsoidalCs2DType], My3DPoint.by_ref
end
