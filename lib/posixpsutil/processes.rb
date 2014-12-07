require 'ostruct'

class PsutilError < StandardError
  
  def to_s
    @message
  end
end

class NoSuchProcess < PsutilError
   
  def initialize(opt={})
    raise ArgumentError if opt[:pid].nil?
    @pid = opt[:pid]
    @name = opt[:name]
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
    @pid = opt[:pid]
    @name = opt[:name]
    if opt[:msg].nil?
      if @pid && @name
        details = "(pid=#{@pid}, name=#{@name.to_s})"
      elsif pid
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
  
end


