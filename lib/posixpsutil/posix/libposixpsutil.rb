require 'ffi'
require 'rbconfig'
require_relative '../common'

module PosixPsutil

# C extention for posix platform
module LibPosixPsutil
  extend FFI::Library

  case RbConfig::CONFIG['host_os']
  when OSX_PLAFORM
    ffi_lib COMMON::LibOSXName
  else
    ffi_lib COMMON::LibPosixName
  end

  attach_function 'get_clock_ticks', [], :long
  attach_function 'get_page_size', [], :long
  attach_function 'get_priority', [:long, :pointer], :int
  attach_function 'set_priority', [:long, :int], :int

  CLOCK_TICKS = get_clock_ticks
  PAGE_SIZE = get_page_size
end

end

