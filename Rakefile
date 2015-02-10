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

task :example => [:build] do
  Dir.glob('example/*.rb').each do |file|
    sh "ruby #{file}"
  end
end

task :build do
  if CONFIG['host_os'] =~ /linux/
    dir = 'ext/linux'
  else
    dir = 'ext/posix'
  end
  Dir.chdir(dir) do
    sh 'make'
  end
end

task :install => [:clean] do
  if CONFIG['host_os'] =~ /linux/
    Dir.chdir('ext/linux')
  else
    Dir.chdir('ext/posix')
  end
  sh 'make install'
  #TODO Don't really install it now
end

Rake::TestTask.new do |t|
  Rake::Task['build'].invoke
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/test_*.rb'
  t.verbose = false
  # so we can type `rake TEST="processes.rb"` instead of `rake TEST="test/test_processes.rb"`
  test = ENV['TEST']
  unless test.nil?
    Dir.chdir 'test'
    ENV['TEST'] = 'test_' + test unless test.start_with? 'test_'
  end
end


task :default => :test
