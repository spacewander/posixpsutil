# This file is required by Rakefile and ext/Rakefile, to make thing dry
require 'rbconfig'

include RbConfig

def make_srcs(task=nil, src_dir='ext')
  if !ENV['platform'].nil?
    params = "platform='#{ENV['platform']}'"
  elsif CONFIG['host_os'] =~ /linux/i
    params = "platform='linux'"
  else
    params = "platform='posix'"
  end

  params = "install " + params if task == :install
  Dir.chdir src_dir do
    sh "make #{params}"
  end
end

