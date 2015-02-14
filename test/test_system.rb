require 'minitest/autorun'
require 'rbconfig'

os = RbConfig::CONFIG['host_os']
case os
  when /darwin|mac os|solaris|bsd|aix/i
    require_relative 'posix'
  when /linux/i
    require_relative 'linux'
  else
    raise RuntimeError, "unsupported os: #{os.inspect}"
end
