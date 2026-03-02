module Proj
  module Api
    attach_function :proj_coordoperation_is_instantiable, :proj_coordoperation_is_instantiable, [:pointer, :pointer], :int
    attach_function :proj_coordoperation_get_method_info, :proj_coordoperation_get_method_info, [:pointer, :pointer, :pointer], :string
    attach_function :proj_coordoperation_get_param_count, :proj_coordoperation_get_param_count, [:pointer, :pointer], :int
  end
end
