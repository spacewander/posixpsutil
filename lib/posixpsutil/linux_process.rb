require_relative 'common'
require_relative 'psutil_error'

class PlatformSpecificProcess
  # for class scope variable which should be memorized
  @@terminal_map = {}

  def initialize(pid)
    raise ArgumentError.new("pid is illegal!") if pid.nil? || pid <= 0
    @pid = pid
    @name = nil
  end


  # Decorator which translates Errno::ENOENT, Errno::ESRCH into AccessDenied;
  # Errno::EPERM, Errno::EACCES into NoSuchProcess.
  def self.wrap_exceptions(method)
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

  def cmdline
    File.new("/proc/#{@pid}/cmdline").read.split("\x00").delete_if {|x| !x}
  end
  wrap_exceptions :cmdline

  def cpu_times
    st = IO.read("/proc/#{@pid}/stat").strip
    # ignore the first two values ("pid (exe)")
    st = st[/\) (.*$)/, 1]
    values = st.split(' ')
    utime = values[11].to_f / COMMON::CLOCK_TICKS
    stime = values[12].to_f / COMMON::CLOCK_TICKS
    OpenStruct.new(user:utime, system:stime)
  end

  def exe
    begin
      # readlink() might return paths containing null bytes ('\x00').
      # Certain names have ' (deleted)' appended. Usually this is
      # bogus as the file actually exists. Either way that's not
      # important as we don't want to discriminate executables which
      # have been deleted.
      exe = File.readlink("/proc/#{@pid}/exe").split("\x00")[0]
      if exe.end_with?(' (deleted)') && !File.exists(exe)
        exe = exe[0...-10]
      end
      exe
    rescue Errno::ENOENT, Errno::ESRCH
      # no such file error; might be raised also if the
      # path actually exists for system processes with
      # low pids (about 0-20)
      if File.exists? "/proc/#{@pid}"
        return ""
      else
        raise NoSuchProcess(pid:@pid, name:name())
      end
      raise
    rescue Errno::EPERM, Errno::EACCES
      raise AccessDenied.new(pid:@pid, name:name())
    end
  end

  def io_counters
    rcount = wcount = rbytes = wbytes = nil
    IO.readlines("/proc/#{@pid}/io").each do |line|
      if !rcount && line.start_with?("syscr")
        rcount = line.split[1] 
      elsif !wcount && line.start_with?("syscw")
        wcount = line.split[1]
      elsif !rbytes && line.start_with?("read_bytes")
        rbytes = line.split[1]
      elsif !wbytes && line.start_with?("write_bytes")
        wbytes = line.split[1]
      end
    end
    [rcount, wcount, rbytes, wbytes].each do |item|
      raise NotImplementedError.new(
        "couldn't read all necessary info from /proc/#{@pid}/io") unless item
    end
    OpenStruct.new(rcount: rcount, wcount: wcount, 
                   rbytes: rbytes, wbytes: wbytes)
  end
  wrap_exceptions :io_counters

  def name
    @name = File.new("/proc/#{@pid}/stat").readline.
      split(' ')[1][/\((.+?)\)/, 1] unless @name
    @name
  end
  wrap_exceptions :name

  def terminal
    tmap = get_terminal_map
    tty_nr = IO.read("/proc/#{@pid}/stat").split(' ')[6].to_i
    tmap[tty_nr]
  end
  wrap_exceptions :terminal

  def wait(timeout=nil)
    return POSIX::wait_pid(@pid, timeout)
    # maybe raise TimeoutExpired, need not to convert it currently
    #rescue POSIX::TimeoutExpired
  end
  wrap_exceptions :wait

  private

  def get_terminal_map
    if @@terminal_map.empty?
      ret = {}
      list = Dir.glob('/dev/tty*') + Dir.glob('/dev/pts/*')
      list.each do |name|
        begin
          ret[File.stat(name).rdev] = name unless ret.has_key?(name)
        rescue Errno::ENOENT
          next
        end
      end
      @@terminal_map = ret
    end
    @@terminal_map
  end

end
