require 'socket'
require_relative './psutil_error'

module COMMON

# CLOCK_TICKS = 100
CLOCK_TICKS = IO.popen('getconf CLK_TCK').read.to_i
     
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

# this module places helper functions used in all posix platform 
# Processes implementions
module POSIX

# Check whether pid exists in the current process table."""
def pid_exists(pid)
  # According to "man 2 kill" PID 0 has a special meaning:
  # it refers to <<every process in the process group of the
  # calling process>> so we don't want to go any further.
  # If we get here it means this UNIX platform *does* have
  # a process with id 0.
  return true if pid == 0
  begin
    Process.kill(0, pid)
    return true
  rescue Errno::ESRCH # No such process
    return false
  rescue Errno::EPERM
    # EPERM clearly means there's a process to deny access to
    return true
  rescue RangeError # the given pid is invalid.
    return false
  end
end

require 'timeout'

# Wait for process with pid 'pid' to terminate and return its
# exit status code as an integer.
#
# If pid is not a children of Process.pid (current process) just
# waits until the process disappears and return nil.
#
# If pid does not exist at all return nil immediately.
#
# Raise Timeout::Error on timeout expired.
def wait_pid(pid, timeout=nil)
  def check_timeout(delay, stop_at, timeout)
    if timeout
      raise Timeout::Error if Time.now >= stop_at
    end
    sleep(delay)
    delay * 2 < 0.04 ? delay * 2 : 0.04
  end

  if timeout
    waitcall = Proc.new { Process.wait(pid, Process::WNOHANG)}
    stop_at = Time.now + timeout
  else
    waitcall = Proc.new { Process.wait(pid)}
  end

  delay = 0.0001
  while true
    begin
      retpid = waitcall.call()
    rescue Errno::EINTR
      delay = check_timeout(delay, stop_at, timeout)
      next
    rescue Errno::ECHILD
      # This has two meanings:
      # - pid is not a child of Process.pid in which case
      #   we keep polling until it's gone
      # - pid never existed in the first place
      # In both cases we'll eventually return nil as we
      # can't determine its exit status code.
      while true
        return nil unless pid_exists(pid)
        delay = check_timeout(delay, stop_at, timeout)
      end
    end

    unless retpid
      # WNOHANG was used, pid is still running
      delay = check_timeout(delay, stop_at, timeout)
      next
    end

    # process exited due to a signal; return the integer of
    # that signal
    if $?.signaled?
      return $?.termsig
    # process exited using exit(2) system call; return the
    # integer exit(2) system call has been called with
    elsif $?.exited?
      return $?.exitstatus
    else
      # should never happen
      raise RuntimeError.new("unknown process exit status")
    end
  end
end

end
