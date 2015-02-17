require 'ffi'
require_relative '../common'

module PosixPsutil

# C extention for linux platform
module LibPosixPsutil
  extend FFI::Library
  ffi_lib COMMON::LibLinuxName
  
  attach_function 'get_clock_ticks', [], :long
  attach_function 'get_page_size', [], :long
  attach_function 'set_priority', [:long, :int], :int

  attach_function 'get_cpu_affinity', [:long, :pointer, :pointer], :int
  attach_function 'set_cpu_affinity', [:long, :pointer, :int], :int
  attach_function 'get_ionice', [:long, :pointer, :pointer], :int
  attach_function 'set_ionice', [:long, :int, :int], :int
  attach_function 'get_rlimit', [:long, :int, :pointer, :pointer], :int
  attach_function 'set_rlimit', [:long, :int, :long_long, :long_long], :int

  CLOCK_TICKS = get_clock_ticks
  PAGE_SIZE = get_page_size
end

end
