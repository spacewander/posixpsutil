require_relative 'common'
require_relative 'linux_helper'
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

PAGE_SIZE = COMMON::PAGE_SIZE
CLOCK_TICKS = COMMON::CLOCK_TICKS

class PlatformSpecificProcess < PsutilHelper::Processes
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
    IO.read("/proc/#{@pid}/cmdline").split("\x00").delete_if {|x| !x}
  end

  def cpu_times
    st = IO.read("/proc/#{@pid}/stat").strip
    # ignore the first two values ("pid (exe)")
    st = st[/\) (.*$)/, 1]
    values = st.split(' ')
    utime = values[11].to_f / CLOCK_TICKS
    stime = values[12].to_f / CLOCK_TICKS
    OpenStruct.new(user:utime, system:stime)
  end

  def create_time
    st = IO.read("/proc/#{@pid}/stat").strip
    st = st[/\) (.*$)/, 1]
    values = st.split(' ')
    @@boot_time = PsutilHelper::boot_time() if @@boot_time.nil?
    return @@boot_time + values[19].to_f / CLOCK_TICKS
  end

  def cwd
    File.readlink("/proc/#{@pid}/cwd").sub("\x00", "")
  end

  def cpu_affinity
    # TODO implement it with C
  end

  def cpu_affinity=(cpus)
    # TODO
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

  def ionice
    # TODO implement it with C
  end

  def set_ionice(ioclass, value)
    # TODO implement it with C
  end

  def memory_info
    vms, rss = File.new("/proc/#{@pid}/statm").readline.split[0...2]
    OpenStruct.new(vms: vms.to_i * PAGE_SIZE, 
                   rss: rss.to_i * PAGE_SIZE)
  end

  #  ============================================================
  # | FIELD  | DESCRIPTION                         | AKA  | TOP  |
  #  ============================================================
  # | rss    | resident set size                   |      | RES  |
  # | vms    | total program size                  | size | VIRT |
  # | shared | shared pages (from shared mappings) |      | SHR  |
  # | text   | text ('code')                       | trs  | CODE |
  # | lib    | library (unused in Linux 2.6)       | lrs  |      |
  # | data   | data + stack                        | drs  | DATA |
  # | dirty  | dirty pages (unused in Linux 2.6)   | dt   |      |
  #  ============================================================
  def memory_info_ex
    info = File.new("/proc/#{@pid}/statm").readline.split[0...7]
    vms, rss, shared, text, lib, data, dirty = info.map {|i| i.to_i * PAGE_SIZE}
    OpenStruct.new(vms: vms, rss: rss, shared: shared, text: text, lib: lib,
                  data: data, dirty: dirty)
  end
  
  def name
    @name = File.new("/proc/#{@pid}/stat").readline.
      split(' ')[1][/\((.+?)\)/, 1] unless @name
    @name
  end

  def nice
    # A value in the range 19 (low priority) to -20 (high priority).
    # Use `man proc` to see the difference between priority and nice.
    IO.read("/proc/#{@pid}/stat").split[18].to_i
  end

  def nice=
    # TODO will be inplemented with C
  end

  def num_ctx_switches
    vol = nonvol = nil
    IO.readlines("/proc/#{@pid}/status").each do |line|
      if line.start_with?("voluntary_ctxt_switches")
        vol = line.split[1].to_i
      elsif line.start_with?("nonvoluntary_ctxt_switches")
        nonvol = line.split[1].to_i
      end

      if vol && nonvol
        return OpenStruct.new(voluntary: vol, involuntary: nonvol)
      end
    end
    msg = <<-EOF.gsub(/(?:^\s+\||\n)/, '')
      |'voluntary_ctxt_switches' and 'nonvoluntary_ctxt_switches'
      | fields were not found in /proc/#{@pid}/status; the kernel is 
      |probably older than 2.6.23
    EOF
    raise NotImplementedError.new(msg)
  end

  def num_fds
    Dir.entries("/proc/#{@pid}/fd").size - 2 # ignore '.' and '..'
  end

  def num_threads
    IO.readlines("/proc/#{@pid}/status").each do |line|
      return line.split[1].to_i if line.start_with?("Threads:")
    end
    raise NotImplementedError.new("line not found")
  end
  
  def ppid
    IO.readlines("/proc/#{@pid}/status").each do |line|
      return line.split[1].to_i if line.start_with?("PPid:")
    end
    raise NotImplementedError.new("line not found")
  end

  def rlimit(resource, limits=nil)
    # TODO implement it with C
  end

  def status
    PROC_STATUSES.default = '?'
    IO.readlines("/proc/#{@pid}/status").each do |line|
      # PROC_STATUSES will return '?' if given key is not existed
      return PROC_STATUSES[line.split[1]] if line.start_with?('State:')
    end
  end

  def terminal
    tmap = get_terminal_map
    tty_nr = IO.read("/proc/#{@pid}/stat").split(' ')[6].to_i
    tmap[tty_nr] # if tty_nr is not a key of tmap, retun nil
  end

  def threads
    thread_ids = Dir.entries("/proc/#{@pid}/task").sort - ['.', '..']
    retlist = []
    thread_ids.each do |id|
      begin
        st = IO.read("/proc/#{@pid}/task/#{id}/stat").strip
        st = st[/\) (.*$)/, 1]
        values = st.split(' ')
        utime = values[11].to_f / COMMON::CLOCK_TICKS
        stime = values[12].to_f / COMMON::CLOCK_TICKS
        retlist.push(OpenStruct.new(thread_id: id, 
                                    user_time: utime, system_time: stime))
      rescue Errno::ENOENT
        # check if process disappeared on us
        # may raise NoSuchProcess
        raise NoSuchProcess.new(pid: @pid) unless File.exists?("/proc/#{@pid}")
        next
      end
    end
    retlist
  end

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

  def self.wrap_action_except_for(wrapper, methods)
    methods = self.instance_methods(false) - methods
    wrapper = method(wrapper)
    methods.each do |method|
      wrapper.call(method)
    end
  end

  wrap_action_except_for :wrap_exceptions, [:exe]

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
