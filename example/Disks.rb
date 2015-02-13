#!/usr/bin/env ruby
# encoding: UTF-8

require_relative '../lib/posixpsutil'

Disks = PosixPsutil::Disks
puts "Start running the Disks example"
disk_partitions = Disks.disk_partitions
puts "There are #{disk_partitions.size} devices"
puts "The first device: #{disk_partitions[0].device}"
puts "Its mountpoint: #{disk_partitions[0].mountpoint}"
puts "Its filesystem: #{disk_partitions[0].fstype}"
puts "Its options: #{disk_partitions[0].opts}"

puts ""

puts "Disk usage of / : "
root = Disks.disk_usage('/')
puts "Total : #{root.total}"
puts "Used : #{root.used}"
puts "Free : #{root.free}"
puts "Percent : #{root.percent}"

puts "Disk usage of /home : "
home = Disks.disk_usage('/home')
puts "Total : #{home.total}"
puts "Used : #{home.used}"
puts "Free : #{home.free}"
puts "Percent : #{home.percent}"

begin
  Disks.disk_usage('/opt')
rescue
  puts "WARNING: this method receive a disk name instead of a path"
end

puts ""
puts "Disk IO counters(total) : #{Disks.disk_io_counters(false)}"
puts "Disk IO counters(perdisk) : "
Disks.disk_io_counters().each_pair {|name, disk| puts "#{name} : #{disk}"}
puts ""

