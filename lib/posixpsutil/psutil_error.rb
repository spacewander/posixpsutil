module PosixPsutil
class PsutilError < StandardError
  
  def to_s
    @message
  end
end

# Raise it if the process behind doesn't exist 
# when you try to call a method of a Process instance.
class NoSuchProcess < PsutilError
  # should be used at least like NoSuchProcess.new(pid: xxx) 
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

# Raise it when the access is denied, a wrapper of ENOENT::EACCES
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
end
