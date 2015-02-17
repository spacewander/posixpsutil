#!/usr/bin/env rake
# encoding: UTF-8

begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

Bundler::GemHelper.install_tasks

require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rbconfig'
include RbConfig

CLEAN.include(
  '**/*.core',              # Core dump files
  '**/*.gem',               # Gem files
  '**/*.o',                 # C object file
  '**/*.d',                 # C dependency file
  '**/*.so',                # dynamic load library
  '**/*.dylib'              # dynamic load library on OS X
)

desc "run all examples one by one"
task :example => [:build] do
  Dir.glob('example/*.rb').each do |file|
    sh "ruby #{file}"
  end
end

def make_srcs(task=nil)
  if !ENV['platform'].nil?
    params = "platform='#{ENV['platform']}'"
  elsif CONFIG['host_os'] =~ /linux/i
    params = "platform='linux'"
  else
    params = "platform='posix'"
  end

  params = "install " + params if task == :install
  Dir.chdir 'ext' do
    sh "make #{params}"
  end
end

desc "build C extention"
task :build do
  make_srcs
end

task :install => [:clean] do
  make_srcs :install
  #TODO Don't really install it now
end

Rake::TestTask.new do |t|
  Rake::Task['build'].invoke
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/test_*.rb'
  t.verbose = false
  # so we can type `rake TEST="processes"` instead of `rake TEST="test/test_processes.rb"`
  test = ENV['TEST']
  unless test.nil?
    ENV['TEST'] = 'test/test_' + test unless test.start_with? 'test/test_'
    ENV['TEST'] += '.rb' unless test.end_with? '.rb'
  end
end


task :default => :test
