class PlatformSpecificProcess
  def initialize(pid)
    raise ArgumentError.new("pid is illegal!") if pid.nil? || pid <= 0
    @pid = pid
  end

  def name
    File.new("/proc/#{@pid}/stat").readline.split(' ')[1][/\((.+?)\)/, 1]
  end

  def cmdline
    File.new("/proc/#{@pid}/cmdline").read.split("\x00").delete_if {|x| !x}
  end
end
