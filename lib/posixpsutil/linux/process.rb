require_relative '../psutil_error'
require_relative '../libc'
require_relative 'helper'
require_relative 'system'
require_relative 'libposixpsutil'

module PosixPsutil

# taken from /fs/proc/array.c
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

# ioprio_* constants http://linux.die.net/man/2/ioprio_get
IOPRIO_CLASS_NONE = 0
IOPRIO_CLASS_RT = 1
IOPRIO_CLASS_BE = 2
IOPRIO_CLASS_IDLE = 3

IOPRIO_CLASS = {
  :none => IOPRIO_CLASS_NONE,
  :rt => IOPRIO_CLASS_RT,
  :be => IOPRIO_CLASS_BE,
  :idle => IOPRIO_CLASS_IDLE
}

PAGE_SIZE = LibPosixPsutil::PAGE_SIZE
CLOCK_TICKS = LibPosixPsutil::CLOCK_TICKS

class PlatformSpecificProcess < PsutilHelper::Processes
  include PsutilHelper
  include NetworkConstance

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
        raise NoSuchProcess.new(pid:@pid, name:@name)
      rescue Errno::EPERM, Errno::EACCES
        raise AccessDenied.new(pid: @pid, name:@name)
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
    if @create_time.nil?
      st = IO.read("/proc/#{@pid}/stat").strip
      st = st[/\) (.*$)/, 1]
      values = st.split(' ')
      @@boot_time = PsutilHelper::boot_time() if @@boot_time.nil?
      @create_time =  @@boot_time + values[19].to_f / CLOCK_TICKS
    end
    @create_time
  end

  def time_used
    (Time.now.to_f - create_time).round 2
  end

  def connections(interface = :inet)
    connection = Connection.new
    unless connection.tmap.key?(interface)
      raise ArgumentError.new("Unknown connection kind #{interface}") 
    end
    inodes = Processes.get_proc_inodes(@pid)
    return [] if inodes.empty?

    ret = []
    connection.tmap[interface].each do |kind|
      f, family, type = kind
      if [AF_INET, AF_INET6].include?(family)
        ret.concat(connection.process_inet("/proc/net/#{f}", 
                                           family, type, inodes, @pid))
      else
        ret.concat(connection.process_unix("/proc/net/#{f}", 
                                           family, inodes, @pid))
      end
    end
    ret.each { |conn| conn.delete_field(:pid) }
  end

  def cwd
    File.readlink("/proc/#{@pid}/cwd").sub("\x00", "")
  end

  def cpu_affinity
    FFI::MemoryPointer.new(:pointer, 1) do |p|
      # p is an double pointer, 
      # we will malloc enough space for the pointer it holds in `get_cpu_affinity`
      cpu_count = FFI::MemoryPointer.new(:int, 1)
      status = LibPosixPsutil.get_cpu_affinity(@pid, p, cpu_count)
      case status
      when 0
        affinity = p.get_pointer(0).get_array_of_long(0, cpu_count.read_int)
        LibC.free p.get_pointer(0)
        return affinity
      when -1 # got nothing
        return []
      else # error occured
        raise SystemCallError.new('in get_cpu_affinity', status)
      end
    end
  end

  def cpu_affinity=(cpus)
    total_cpus = CPU.cpu_count
    seq_len = cpus.size > total_cpus ? total_cpus : cpus.size
    begin
      FFI::MemoryPointer.new(:long, seq_len) do |affinity|
        affinity.write_array_of_long(cpus[0...seq_len])
        status = LibPosixPsutil.set_cpu_affinity(@pid, affinity, seq_len)
        raise SystemCallError.new('in set_cpu_affinity', status) if status != 0
      end
    # The  affinity bit mask mask contains no processors that are currently 
    # physically on the system and permitted to the thread according to any 
    # restrictions that may be imposed by the "cpuset" mechanism 
    # described in cpuset(7)
    rescue Errno::EINVAL
      cpus.each do |cpu|
        if cpu < 0 || cpu >= total_cpus
          raise ArgumentError.new
            "invalid CPU #{cpu} (choose between 0 to #{total_cpus})"
        end
      end
      raise
    end
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
        raise NoSuchProcess.new(pid:@pid)
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
    ioclass = FFI::MemoryPointer.new(:int, 1)
    value = FFI::MemoryPointer.new(:int, 1)
    status = LibPosixPsutil.get_ionice(@pid, ioclass, value)
    raise SystemCallError.new('in get_ionice', status) if status != 0
    OpenStruct.new(ioclass: ioclass.read_int, value: value.read_int)
  end

  def set_ionice(ioclass, value)
    ioclass ||= IOPRIO_CLASS_NONE

    if ioclass.is_a?(Symbol)
      unless IOPRIO_CLASS.key? ioclass
        symbols = ":" + IOPRIO_CLASS.keys.join(', :')
        msg = "Unsupported symbol :#{ioclass}, only support #{symbols}"
        raise ArgumentError.new(msg)
      end
      ioclass = IOPRIO_CLASS[ioclass]
    end

    case ioclass
    when IOPRIO_CLASS_NONE
      raise ArgumentError.new("can't specify value with #{ioclass}") if value
      value = 0
    when IOPRIO_CLASS_RT, IOPRIO_CLASS_BE
      value = 4 if value.nil?
    when IOPRIO_CLASS_IDLE
      raise ArgumentError.new("can't specify value with #{ioclass}") if value
      value = 0
    else
      msg = "ioclass argument expected is an integer between 0 and 3, got #{ioclass}"
      raise ArgumentError.new(msg)
    end
    if value < 0 || value > 7 || value.to_i != value
      msg = "value argument expected is an integer between 0 and 7, got #{value}"
      raise ArgumentError.new(msg)
    end
    status = LibPosixPsutil.set_ionice(@pid, ioclass, value)
    raise SystemCallError.new('in set_ionice', status) if status != 0
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

  if File.exists?("/proc/#{Process.pid}/smaps")

    # Return process's mapped memory regions as a list of nameduples.
    # Fields are explained in 'man proc'; here is an updated (Apr 2012)
    # version: http://goo.gl/fmebo
    def memory_maps
      lines = IO.readlines("/proc/#{@pid}/smaps")
      return [] if lines == [] # smaps file can be empty

      blocks = []
      # the header of each section
      first_line = lines[0]

      region_data = {}
      lines.each do |line|
        fields = line.split(/\s+/, 6)
        if fields[0].end_with?(':')
          value = fields[1].to_i
          # if fields[1] can be convert to number
          if value == 0 && fields[1] != '0'
            next if fields[0].start_with?('VmFlags:')
            raise ValueError.new("don't know how to interpret line #{line}")
          end
          region_data[fields[0]] = value * 1024
        else
          # new block section
          blocks.push([first_line, Marshal.load(Marshal.dump(region_data))])
          region_data.clear
          first_line = line
        end
      end
      # deal with final section
      blocks.push([first_line, region_data])

      maps = []
      blocks.each do |header, data|
        hfields = header.split(/\s+/, 6)
        addr, perms, _, _, _, path = hfields
        # hfields may only have 5 parts
        (path.nil? || path == '')? path = '[anon]' : path.strip!
        maps.push([
          addr,
          perms,
          path,
          data.fetch('Rss:', 0),
          data.fetch('Size:', 0),
          data.fetch('Pss:', 0),
          data.fetch('Shared_Clean:', 0),
          data.fetch('Shared_Dirty:', 0),
          data.fetch('Private_Clean:', 0),
          data.fetch('Private_Dirty:', 0),
          data.fetch('Referenced:', 0),
          data.fetch('Anonymous:', 0),
          data.fetch('Swap:', 0)
        ])
      end
      maps
    end

  else
    def memory_maps
      msg = <<-EOF.gsub(/(?:^\s+\||\n)/, '')
        |couldn't find /proc/#{@pid}/smaps; kernel < 2.6.14 or 
        | CONFIG_MMU kernel configuration option is not enabled
      EOF
      raise NotImplementedError.new(msg)
    end
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

  def nice=(value)
    if value.to_i != value || value < -20 || value > 19
      raise ArgumentError.new("nice expected is an integer between -20 and 19, got #{value}")
    end
    status = LibPosixPsutil.set_priority(@pid, value)
    raise SystemCallError.new("in set_priority", status) if status != 0
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

  def open_files
    retlist = []
    Dir.entries("/proc/#{@pid}/fd").each do |fd|
      next if fd == '.' || fd == '..'
      file = "/proc/#{@pid}/fd/#{fd}"
      if File.symlink?(file)
        begin
          file = File.readlink(file)
        rescue Errno::ENOENT, Errno::ESRCH
          # raise NSP if the process disappeared on us
          next if File.exist?("/proc/#{@pid}")
        end
        # If file is not an absolute path there's no way
        # to tell whether it's a regular file or not,
        # so we skip it. A regular file is always supposed
        # to be absolutized though.
        if file.start_with?('/') && File.file?(file) # regular file only
          retlist.push(OpenStruct.new(path: file, fd: fd.to_i))
        end
      end
    end

    retlist
  end
  
  # data in pmmap_ext is an Array
  def pmmap_ext(data)
    pmmap_ext = ['addr', 'perms', 'path', 'rss', 'size', 'pss', 
                 'shared_clean', 'shared_dirty', 'private_clean', 
                 'private_dirty', 'referenced', 'anonymous', 'swap']
    os_list = []
    data.each do |datum|
      os = OpenStruct.new
      pmmap_ext.each_index {|i| os[pmmap_ext[i]] = datum[i]}
      os_list.push(os)
    end
    os_list
  end

  # data in pmmap_grouped is a Hash
  def pmmap_grouped(data)
    pmmap_grouped = ['rss', 'size', 'pss', 'shared_clean', 
                     'shared_dirty', 'private_clean', 'private_dirty', 
                     'referenced', 'anonymous', 'swap']
    os_list = []
    data.each do |k, v|
      os = OpenStruct.new
      os.path = k
      pmmap_grouped.each_index {|i| os[pmmap_grouped[i]] = v[i]}
      os_list.push(os)
    end
    os_list
  end

  def ppid
    IO.readlines("/proc/#{@pid}/status").each do |line|
      return line.split[1].to_i if line.start_with?("PPid:")
    end
    raise NotImplementedError.new("line not found")
  end

  def rlimit(resource, limits=nil)
    # if pid is 0 prlimit() applies to the calling process and
    # we don't want that
    if @pid == 0
      raise ArgumentError.new("can't use prlimit() against PID 0 process")
    end
    if limits.nil?
      # get
      # On 64-bit system, long long is the same as long, can we replace it with long?
      soft = FFI::MemoryPointer.new(:long_long, 1)
      hard = FFI::MemoryPointer.new(:long_long, 1)
      status = LibPosixPsutil.get_rlimit(@pid, resource, soft, hard)
      raise SystemCallError.new("in get_rlimit", status) if status != 0
      {:soft => soft.read_long_long, :hard => hard.read_long_long}
    else
      # set
      if limits.is_a?(Hash) && limits.key?(:soft) && limits.key?(:hard)
        status = LibPosixPsutil.set_rlimit(@pid, resource, 
                                           limits[:soft], limits[:hard])
        raise SystemCallError.new("in set_rlimit", status) if status != 0
        limits
      else
        raise ArgumentError.new("second argument must be a {:soft, :hard} Hash")
      end
    end 

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
        utime = values[11].to_f / CLOCK_TICKS
        stime = values[12].to_f / CLOCK_TICKS
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

  # assert the process is existed when specific method called
  def self.assert_process_exists(method)
    old_method = instance_method(method)
    define_method method do |*args, &block|
      file = "/proc/#{@pid}"
      # raise NSP if the process disappeared on us
      raise NoSuchProcess.new(pid: @pid) unless File.exists?(file)
      old_method.bind(self).call(*args, &block)
    end
  end
  assert_process_exists :connections

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
end
