#!/usr/bin/env ruby
# encoding: UTF-8

require_relative "../lib/posixpsutil"

Memory = PosixPsutil::Memory
puts "Start running the Memory example"
puts "Virtual memory info:"
puts "Total: #{Memory.virtual_memory.total}"
puts "Available: #{Memory.virtual_memory.available}"
puts "Percent: #{Memory.virtual_memory.percent}"
puts "Used: #{Memory.virtual_memory.used}"
puts "Free: #{Memory.virtual_memory.free}"
puts "Active: #{Memory.virtual_memory.active}"
puts "Inactive: #{Memory.virtual_memory.inactive}"
puts "Buffers: #{Memory.virtual_memory.buffers}"
puts "Cached: #{Memory.virtual_memory.cached}"

puts ""
puts "Swap memory info:"
puts "Total: #{Memory.swap_memory.total}"
puts "Used: #{Memory.swap_memory.used}"
puts "Free: #{Memory.swap_memory.free}"
puts "Percent: #{Memory.swap_memory.percent}"
puts "Sin: #{Memory.swap_memory.sin}"
puts "Sout: #{Memory.swap_memory.sout}"
puts ""

