require 'ostruct'
require 'rbconfig'

os = RbConfig::CONFIG['host_os']
case os
  when /darwin|mac os|solaris|bsd/
    require_relative 'posix_process'
  when /linux/
    require_relative 'linux_process'
  else
    raise RuntimeError, "unknown os: #{os.inspect}"
end

class PsutilError < StandardError
  
  def to_s
    @message
  end
end

class NoSuchProcess < PsutilError
   
  def initialize(opt={})
    raise ArgumentError if opt[:pid].nil?
    @pid = opt[:pid] # pid must given
    @name = opt[:name] || nil
    if opt[:msg].nil?
      if @name
        details = "(pid=#{@pid}, name=#{@name.to_s})"
      else
        details = "(pid=#{@pid})"
      end
      opt[:msg] = "process no longer exists " + details
    end
    @message = opt[:msg]
  end

end

class AccessDenied < PsutilError
  
  def initialize(opt={})
    @pid = opt[:pid] || nil
    @name = opt[:name] || nil
    if opt[:msg].nil?
      if @pid && @name
        details = "(pid=#{@pid}, name=#{@name.to_s})"
      elsif @pid
        details = "(pid=#{@pid})"
      else
        details = ""
      end
      opt[:msg] = "access is denied " + details
    end
    @message = opt[:msg]
  end
end

class Processes
   # Represents an OS process with the given PID.
   # If PID is omitted current process PID (Process.pid) is used.
   # Raise NoSuchProcess if PID does not exist.
   #
   # Note that most of the methods of this class do not make sure
   # the PID of the process being queried has been reused over time.
   # That means you might end up retrieving an information referring
   # to another process in case the original one this instance
   # refers to is gone in the meantime.
   #
   # The only exceptions for which process identity is pre-emptively
   # checked and guaranteed are:

   #  - parent()
   #  - children()
   #  - nice() (set)
   #  - ionice() (set)
   #  - rlimit() (set)
   #  - cpu_affinity (set)
   #  - suspend()
   #  - resume()
   #  - send_signal()
   #  - terminate()
   #  - kill()

   # To prevent this problem for all other methods you can:
   #   - use is_running() before querying the process
   #   - if you're continuously iterating over a set of Process
   #     instances use process_iter() which pre-emptively checks
   #     process identity for every instance
  
  attr_reader :identity

  def initialize(pid=nil)
    pid = Process.pid unless pid
    @pid = pid
    raise ArgumentError.new("pid must be 
                            a positive integer (got #{@pid})") if @pid <= 0
    @name = nil
    @exe = nil
    @create_time = nil 
    @gone = false
    @hash = nil
    @proc = PlatformSpecificProcess.new(@pid)
    @last_sys_cpu_times = nil
    @last_proc_cpu_times = nil
    begin
      create_time
    rescue AccessDenied
      # we should never get here as AFAIK we're able to get
      # process creation time on all platforms even as a
      # limited user
    rescue NoSuchProcess
      msg = "no process found with pid #{@pid}"
      raise NoSuchProcess(@pid, nil, msg)
    end
    # This part is supposed to indentify a Process instance
    # univocally over time (the PID alone is not enough as
    # it might refer to a process whose PID has been reused).
    # This will be used later in == and is_running().
    @identity = [@pid, @create_time]
  end

  def to_s
    begin
      return "(pid=#{@pid}, name=#{name()})"
    rescue NoSuchProcess
      return "(pid=#{@pid} (terminated))"
    rescue AccessDenied
      return "(pid=#{@pid})"
    end
  end

  def ==(other)
    # Test for equality with another Process object based
    # on PID and creation time.
    return self.class == other.class && @identity == other.identity
  end
  alias_method :eql?, :==

  def !=(other)
    return !(self == other)
  end

  def name
    return ""
  end

  def create_time
    nil
  end

end


