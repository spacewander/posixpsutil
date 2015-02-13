#!/usr/bin/env ruby
# encoding: UTF-8

require 'rbconfig'
require_relative 'posixpsutil/common'

os = RbConfig::CONFIG['host_os']
# load process module
require_relative 'posixpsutil/process'
# load system module
case os
  when PosixPsutil::COMMON::NON_LINUX_PLATFORM
    require_relative 'posixpsutil/posix/system'
  when PosixPsutil::COMMON::LINUX_PLATFORM
    require_relative 'posixpsutil/linux/system'
  else
    raise RuntimeError, "unsupported os: #{os.inspect}"
end
