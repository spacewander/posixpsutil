require 'ffi'
require_relative '../common'

module PosixPsutil

# C extention for linux platform
module LibPosixPsutil
  extend FFI::Library
  ffi_lib COMMON::LibLinuxName
  
  attach_function 'get_cpu_affinity', [:long, :pointer, :pointer], :int
  attach_function 'set_cpu_affinity', [:long, :pointer, :int], :int
  attach_function 'get_ionice', [:long, :pointer, :pointer], :int
  attach_function 'set_ionice', [:long, :int, :int], :int
end

end
