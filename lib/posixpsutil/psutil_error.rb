module PosixPsutil
class PsutilError < StandardError
  
  def to_s
    @message
  end
end

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
