#!/usr/bin/env ruby
# encoding: UTF-8

require_relative '../lib/posixpsutil'

disk_parititions = Disks.disk_parititions
puts "There are #{disk_parititions.length} devices"
puts "The first device: #{disk_parititions[0].device}"
puts "Its mountpoint: #{disk_parititions[0].mountpoint}"
puts "Its filesystem: #{disk_parititions[0].fstype}"
puts "Its options: #{disk_parititions[0].opts}"
puts "Its size: #{disk_parititions[0].size}"

puts ""

puts "Disk usage of / : #{Disks.disk_usage('/')}"
puts "Disk usage of /opt : #{Disks.disk_usage('/opt')}"

puts ""
puts "Disk IO counters : #{Disks.disk_io_counters(false)}"

