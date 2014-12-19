require_relative 'common'
require_relative 'psutil_error'

PROC_STATUSES = {
    "R" => COMMON::STATUS_RUNNING,
    "S" => COMMON::STATUS_SLEEPING,
    "D" => COMMON::STATUS_DISK_SLEEP,
    "T" => COMMON::STATUS_STOPPED,
    "t" => COMMON::STATUS_TRACING_STOP,
    "Z" => COMMON::STATUS_ZOMBIE,
    "X" => COMMON::STATUS_DEAD,
    "x" => COMMON::STATUS_DEAD,
    "K" => COMMON::STATUS_WAKE_KILL,
    "W" => COMMON::STATUS_WAKING
}

class PlatformSpecificProcess
  # for class scope variable which should be memorized
  @@terminal_map = {}
  @@boot_time = nil

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

  def create_time
    st = IO.read("/proc/#{@pid}/stat").strip
    st = st[/\) (.*$)/, 1]
    values = st.split(' ')
    @@boot_time = PsutilHelper::boot_time() if @@boot_time.nil?
    return @@boot_time + values[19].to_f / COMMON::CLOCK_TICKS
  end
  wrap_exceptions :create_time

  def cwd
    File.readlink("/proc/#{@pid}/cwd").sub("\x00", "")
  end
  wrap_exceptions :cwd

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

  def gids
    IO.readlines("/proc/#{@pid}/status").each do |line|
      if line.start_with?("Gid:")
        _, real, effective, saved, _ = line.split
        return OpenStruct.new(real: real.to_i, effective: effective.to_i, 
                             saved: saved.to_i)
      end
    end
    # impossible to reach here
    raise NotImplementedError.new('line not found')
  end
  wrap_exceptions :gids

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

  def ionice
    # TODO implement it with C
  end

  def set_ionice(ioclass, value)
    # TODO implement it with C
  end

  def name
    @name = File.new("/proc/#{@pid}/stat").readline.
      split(' ')[1][/\((.+?)\)/, 1] unless @name
    @name
  end
  wrap_exceptions :name

  def nice
    # A value in the range 19 (low priority) to -20 (high priority).
    # Use `man proc` to see the difference between priority and nice.
    IO.read("/proc/#{@pid}/stat").split[18].to_i
  end
  wrap_exceptions :nice

  def nice=
    # TODO will be inplemented with C
  end
  wrap_exceptions :nice=

  def num_fds
    Dir.entries("/proc/#{@pid}/fd").size - 2 # ignore '.' and '..'
  end
  wrap_exceptions :num_fds
  
  def status
    PROC_STATUSES.default = '?'
    IO.readlines("/proc/#{@pid}/status").each do |line|
      # PROC_STATUSES will return '?' if given key is not existed
      return PROC_STATUSES[line.split[1]] if line.start_with?('State:')
    end
  end
  wrap_exceptions :status

  def terminal
    tmap = get_terminal_map
    tty_nr = IO.read("/proc/#{@pid}/stat").split(' ')[6].to_i
    tmap[tty_nr] # if tty_nr is not a key of tmap, retun nil
  end
  wrap_exceptions :terminal

  def uids
    IO.readlines("/proc/#{@pid}/status").each do |line|
      if line.start_with?("Uid:")
        _, real, effective, saved, _ = line.split
        return OpenStruct.new(real: real.to_i, effective: effective.to_i, 
                             saved: saved.to_i)
      end
    end
    # impossible to reach here
    raise NotImplementedError.new('line not found')
  end
  wrap_exceptions :uids

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
          ret[File.stat(name).rdev] = name unless ret.key?(name)
        rescue Errno::ENOENT
          next
        end
      end
      @@terminal_map = ret
    end
    @@terminal_map
  end

end
