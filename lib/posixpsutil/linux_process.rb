require_relative 'psutil_error'

class PlatformSpecificProcess
  def initialize(pid)
    raise ArgumentError.new("pid is illegal!") if pid.nil? || pid <= 0
    @pid = pid
  end


  # Decorator which translates Errno::ENOENT, Errno::ESRCH into AccessDenied;
  # Errno::EPERM, Errno::EACCES into NoSuchProcess.
  def self.wrap_exception(method)
    old_method = instance_method(method)
    define_method method do |*args, &block|
      begin
        old_method.bind(self).call(*args, &block)
      rescue Errno::ENOENT, Errno::ESRCH
        raise NoSuchProcess.new(pid:@pid)
      rescue Errno::EPERM, Errno::EACCES
        raise AccessDenied
      end
    end
  end

  def name
    File.new("/proc/#{@pid}/stat").readline.split(' ')[1][/\((.+?)\)/, 1]
  end
  wrap_exception :name

  def cmdline
    File.new("/proc/#{@pid}/cmdline").read.split("\x00").delete_if {|x| !x}
  end
  wrap_exception :cmdline

end
