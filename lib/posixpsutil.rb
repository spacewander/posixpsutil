#!/usr/bin/env ruby
# encoding: UTF-8

require 'rbconfig'

os = RbConfig::CONFIG['host_os']
require_relative 'posixpsutil/processes'
case os
  when /darwin|mac os|solaris|bsd/
    require_relative 'posixpsutil/posix'
  when /linux/
    require_relative 'posixpsutil/linux'
  else
    raise RuntimeError, "unknown os: #{os.inspect}"
end
