#!/usr/bin/env ruby
# encoding: UTF-8

require_relative '../lib/posixpsutil'

puts "Start running the PosixPsutil::Process example"
p = PosixPsutil::Process.new()
puts "Currently PosixPsutil::Process Module support those class methods:"
PosixPsutil::Process.public_methods(false).each { |method| puts method }
puts ''

puts "And those instance methods:"
p.public_methods(false).each { |method| puts method }
puts ''

puts "Current running PosixPsutil::Process "
puts PosixPsutil::Process.process_iter
puts ''

puts 'Does Process with pid=1111 exist?'
if PosixPsutil::Process.pid_exists(1111)
  existed_process = PosixPsutil::Process.new(1111)
  puts "Yes, it is there: #{existed_process}"
else
  puts 'No, I can not find it'
end
puts ''

puts "Current process is #{p}"
puts "Its parent is #{p.parent}"
puts "Its children are #{p.children}"
puts ""
puts "List its attributes below"
attrs = p.to_hash
attrs.each do |k, v|
  puts "#{k} : #{v}"
end
puts ""
