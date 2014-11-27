require 'socket'

module COMMON

def self.usage_percent(used, total, _round=nil)
  # Calculate percentage usage of 'used' against 'total'.
  begin
      ret = (used / total.to_f) * 100
  rescue ZeroDivisionError
      ret = 0
  end
  if _round
      return ret.round(_round)
  else
      return ret
  end
end
  
end

module NetworkConstance
  AF_INET = Socket::PF_INET
  AF_INET6 = Socket::PF_INET6 
  AF_UNIX = Socket::PF_UNIX
  SOCK_STREAM = Socket::SOCK_STREAM
  SOCK_DGRAM = Socket::SOCK_DGRAM

  CONN_ESTABLISHED = "ESTABLISHED"
  CONN_SYN_SENT = "SYN_SENT"
  CONN_SYN_RECV = "SYN_RECV"
  CONN_FIN_WAIT1 = "FIN_WAIT1"
  CONN_FIN_WAIT2 = "FIN_WAIT2"
  CONN_TIME_WAIT = "TIME_WAIT"
  CONN_CLOSE = "CLOSE"
  CONN_CLOSE_WAIT = "CLOSE_WAIT"
  CONN_LAST_ACK = "LAST_ACK"
  CONN_LISTEN = "LISTEN"
  CONN_CLOSING = "CLOSING"
  CONN_NONE = "NONE"

  # http://students.mimuw.edu.pl/lxr/source/include/net/tcp_states.h
  TCP_STATUSES = {
      "01"=> CONN_ESTABLISHED,
      "02"=> CONN_SYN_SENT,
      "03"=> CONN_SYN_RECV,
      "04"=> CONN_FIN_WAIT1,
      "05"=> CONN_FIN_WAIT2,
      "06"=> CONN_TIME_WAIT,
      "07"=> CONN_CLOSE,
      "08"=> CONN_CLOSE_WAIT,
      "09"=> CONN_LAST_ACK,
      "0A"=> CONN_LISTEN,
      "0B"=> CONN_CLOSING
  }

end

# this module places all classes can be used both in Processes and in other modules
module PsutilHelper
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
        if filter_inodes.include?(inode)
          inet_list = {inode: inode, laddr: decode_address(line[1]), 
                       raddr: decode_address(line[2]), family: family, 
                       type: type, status: CONN_NONE}
          inet_list[:status] = TCP_STATUSES[line[3]] if type == SOCK_STREAM
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
        if filter_inodes.include?(inode)
          inet_list = {inode: inode, raddr: nil, family: family, 
                       type: line[4].to_i, status: CONN_NONE, path: ''}
          inet_list[:path] = line[-1] if line.size == 8
          ret.push(inet_list)
        end # if inode included
      end # each lines
      ret
    end

  end

end
