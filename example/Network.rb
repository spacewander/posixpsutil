#!/usr/bin/env ruby
# encoding: UTF-8

require_relative '../lib/posixpsutil'

puts "Net io counter for eth0 :"
netios = Network.net_io_counters(true)
netio = netios[:eth0]
puts "Bytes sent: #{netio.bytes_sent()}"
puts "Bytes recv: #{netio.bytes_recv()}"
puts "Packets sent: #{netio.packets_sent()}"
puts "Packets recv: #{netio.packets_recv()}"
puts "Errin : #{netio.errin()}"
puts "Errout : #{netio.errout()}"
puts "Dropin : #{netio.dropin()}"
puts "Dropout : #{netio.dropout()}"

puts "\nNet io counter for lo :"
netio = netios[:lo]
puts "Bytes sent: #{netio.bytes_sent()}"
puts "Bytes recv: #{netio.bytes_recv()}"
puts "Packets sent: #{netio.packets_sent()}"
puts "Packets recv: #{netio.packets_recv()}"
puts "Errin : #{netio.errin()}"
puts "Errout : #{netio.errout()}"
puts "Dropin : #{netio.dropin()}"
puts "Dropout : #{netio.dropout()}"

puts "\nNet connections : "
Network.net_connections().each do |conn|
  print "Inode: #{conn.inode} "
  print "Fd: #{conn.fd}"
  print "Family: #{conn.family} "
  print "Type: #{conn.type} "
  print "Local address: #{conn.laddr} "
  print "Remote address: #{conn.raddr} "
  print "Status: #{conn.status} "
  print "Pid: #{conn.pid}\n"
end

