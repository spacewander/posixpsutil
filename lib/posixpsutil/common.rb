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
