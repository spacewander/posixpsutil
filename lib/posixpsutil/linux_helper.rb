require 'ipaddr'
require 'ostruct'
require_relative './common'

# this module places all classes can be used both in Processes and in other modules
module PsutilHelper

  class Processes
    # Returns a list of PIDs currently running on the system.
    def self.pids()
      Dir.entries('/proc').map(&:to_i).delete_if {|x| x == 0}
    end

    # be aware of Permission denied
    def self.get_proc_inodes(pid)
      inodes = {}
      Dir.entries("/proc/#{pid}/fd").each do |fd|
        # get actual path
        begin
          inode = File.readlink("/proc/#{pid}/fd/#{fd}")
          # check if it is a socket
          if inode.start_with? 'socket:['
            inode = inode[8...-1].to_i
            inodes[inode] ||= []
            inodes[inode].push([pid, fd.to_i]) 
          end
        rescue SystemCallError
          next
        end
      end
      inodes
    end

    # format:
    # inodes= {
    #   inode1 => [[pid, fd], [pid, fd], ...]
    #   inode2...
    #   }
    def self.get_all_inodes()
      inodes = {}
      self.pids.each do |pid|
        begin
          inodes.merge!(self.get_proc_inodes(pid))
        rescue SystemCallError => e
          # Not Permission denied?
          raise unless [Errno::ENOENT::Errno, Errno::ESRCH::Errno, 
                        Errno::EPERM::Errno, Errno::EACCES::Errno].include?(e.errno)
        end
      end
      inodes
    end

  end

  # A wrapper on top of /proc/net/* files, retrieving per-process
  # and system-wide open connections (TCP, UDP, UNIX) similarly to
  # "netstat -an".
  # 
  # Note: in case of UNIX sockets we're only able to determine the
  # local endpoint/path, not the one it's connected to.
  # According to [1] it would be possible but not easily.
  #
  # [1] http://serverfault.com/a/417946
  class Connection
    include NetworkConstance

    attr_reader :tmap

    def initialize()
      # proc_filename, family, type
      tcp4 = ["tcp", AF_INET, SOCK_STREAM]
      tcp6 = ["tcp6", AF_INET6, SOCK_STREAM]
      udp4 = ["udp", AF_INET, SOCK_DGRAM]
      udp6 = ["udp6", AF_INET6, SOCK_DGRAM]
      unix = ["unix", AF_UNIX, nil]
      @tmap = {
        all: [tcp4, tcp6, udp4, udp6, unix],
        tcp: [tcp4, tcp6],
        tcp4: [tcp4],
        tcp6: [tcp6],
        udp: [udp4, udp6],
        udp4: [udp4],
        udp6: [udp6],
        unix: [unix],
        inet: [tcp4, tcp6, udp4, udp6],
        inet4: [tcp4, udp4],
        inet6: [tcp6, udp6]
      }
    end

    # parse /proc/net/tcp[46] and /proc/net/udp[46]
    def process_inet(fn, family, type, filter_inodes=[])
      f = File.new(fn)
      f.readline()
      ret = []
      f.readlines.each do |line|
        line = line.split(' ')
        inode = line[9]
        if filter_inodes.empty? || filter_inodes.include?(inode)
          inet_list = {inode: inode.to_i, laddr: decode_address(line[1], family), 
                       raddr: decode_address(line[2], family), family: family, 
                       type: type, status: CONN_NONE}
          inet_list[:status] = TCP_STATUSES[line[3]] if type == SOCK_STREAM
          inet_list = OpenStruct.new inet_list
          ret.push(inet_list)
        end # if inode included
      end # each lines
      ret
    end

    # parse /proc/net/unix 
    def process_unix(fn, family, filter_inodes=[])
      f = File.new(fn)
      f.readline()
      ret = []
      f.readlines.each do |line|
        line = line.split(' ')
        inode = line[6]
        if filter_inodes.empty? || filter_inodes.include?(inode)
          inet_list = {inode: inode.to_i, raddr: nil, family: family, 
                       type: line[4].to_i, status: CONN_NONE, path: ''}
          inet_list[:path] = line[-1] if line.size == 8
          inet_list = OpenStruct.new inet_list
          ret.push(inet_list)
        end # if inode included
      end # each lines
      ret
    end

    # Accept an "ip:port" address as displayed in /proc/net/*
    # and convert it into a human readable form, like:
    # "0500000A:0016" -> ("10.0.0.5", 22)
    # "0000000000000000FFFF00000100007F:9E49" -> ("::ffff:127.0.0.1", 40521)
    # The IP address portion is a little or big endian four-byte
    # hexadecimal number; that is, the least significant byte is listed
    # first, so we need to reverse the order of the bytes to convert it
    # to an IP address.
    # The port is represented as a two-byte hexadecimal number.
    # Reference:
    # http://linuxdevcenter.com/pub/a/linux/2000/11/16/LinuxAdmin.html
    def decode_address(addr, family)
      ip, port = addr.split(':')
      # this usually refers to a local socket in listen mode with
      # no end-points connected
      return nil if !port || port == '0000'
      # convert /proc style ip and port 
      # to addrinfo string according to family and endian
      if '\x00\x01'.unpack('S') == '\x00\x01'.unpack('S<') # little endian
        # first going decoding the hexadecimal
        # then converting to 32 bit integers in small endian
        # encoding these integers with big endian
        # encoding the result in hexadecimal
        ip = [ip].pack('H*').unpack('N*').pack('V*').unpack('H*').first.hex
      end
      port = port.to_i 16
      ip = IPAddr.new(ip, family).to_s
      [ip, port]
    end

  end

end

