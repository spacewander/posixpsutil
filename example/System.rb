#!/usr/bin/env ruby
# encoding: UTF-8

puts "Users detail :"
puts "There are #{System.users.size} users"
user = System.users[0]
puts "One of them is #{user.name}"
puts "His/Her terminal is #{user.terminal}"
puts "The host is #{user.host}"
puts "And has started for #{user.started}"

puts "System boot time is #{System.boot_time()}"

