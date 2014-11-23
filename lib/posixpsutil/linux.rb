require 'ostruct'
require_relative './common'

module CPU

  def self.cpu_times(precpu=false)
    proc_stat = File.new('/proc/stat')
    cpu = proc_stat.readline()
    return get_cpu_fields(cpu) unless precpu
    cpus = []
    loop do
      cpu = proc_stat.readline()
      break unless cpu.start_with?('cpu')
      cpus.push(get_cpu_fields(cpu))
    end
    cpus
  end

  # measure cpu usage percent during an interval
  # WARNING: set a small interval will cause incorrect result
  def self.cpu_percent(interval=0.0, percpu=false)
    if interval > 0.0
      total_start = self.cpu_times(percpu)
      sleep interval
    else
      if percpu
        total_start = @last_per_cpu_times
      else
        total_start = @last_cpu_times
      end
    end

    if percpu
      @last_per_cpu_times = self.cpu_times(true)
      ret = []
      total_start.each_index do |i|
        ret.push(calculate_cpu_percent(total_start[i], @last_per_cpu_times[i]))
      end
      ret
    else
      @last_cpu_times = self.cpu_times()
      calculate_cpu_percent(total_start, @last_cpu_times)
    end
  end
   
  def self.cpu_times_percent(interval=0.0, percpu=false)
    if interval > 0.0
      total_start = self.cpu_times(percpu)
      sleep interval
    else
      if percpu
        total_start = @last_per_cpu_times_fields
      else
        total_start = @last_cpu_times_fields
      end
    end

    if percpu
      @last_per_cpu_times_fields = self.cpu_times(true)
      ret = []
      total_start.each_index do |i|
        ret.push(calculate_cpu_percent_field(total_start[i], @last_per_cpu_times_fields[i]))
      end
      ret
    else
      @last_cpu_times = self.cpu_times()
      calculate_cpu_percent_field(total_start, @last_cpu_times_fields)
    end
  end

  def self.cpu_count(logical=true)
    count = 0
    if !logical
      IO.readlines('/proc/cpuinfo').each do |line|
        count += 1 if line.start_with?('physical id')
      end
      return count
    end

    Dir.entries('/sys/devices/system/cpu').each do |entry|
      count += 1 if entry.start_with?('cpu')
    end
    count -= 2 # except cpuidle and cpufreq
    count
  end

  # The  amount  of  time,  measured in units of +USER_HZ+
  # (1/100ths of a second on most architectures, use sysconf(_SC_CLK_TCK) to obtain the right value), 
  # that the system spent in various states
  # user   (1) Time spent in user mode.
  # nice   (2) Time spent in user mode with low priority (nice).
  # system (3) Time spent in system mode.
  # idle   (4) Time spent in the idle task.  This value should be USER_HZ times the second entry in the /proc/uptime pseudo-file.
  # iowait (since Linux 2.5.41)
  #        (5) Time waiting for I/O to complete.
  # irq (since Linux 2.6.0-test4)
  #        (6) Time servicing interrupts.
  # softirq (since Linux 2.6.0-test4)
  #        (7) Time servicing softirqs.
  # steal (since Linux 2.6.11)
  #        (8) Stolen time, which is the time spent in other operating systems when running in a virtualized environment
  # guest (since Linux 2.6.24)
  #        (9) Time spent running a virtual CPU for guest operating systems under the control of the Linux kernel.
  # guest_nice (since Linux 2.6.33)
  #        (10) Time spent running a niced guest (virtual CPU for guest operating systems under the control of the Linux kernel).
  def self.get_cpu_fields(line)
    stat = line.split(" ")
    # FIXME Ruby doesn't provide sysconf interface, 
    # so I have to guess the value of sysconf(_SC_CLK_TCK)
    clk_tck = 100
    cpu = OpenStruct.new
    cpu.user = stat[1].to_f / clk_tck
    cpu.nice = stat[2].to_f / clk_tck
    cpu.system = stat[3].to_f / clk_tck
    cpu.idle = stat[4].to_f / clk_tck
    cpu.iowait = stat[5].to_f / clk_tck
    cpu.irq = stat[6].to_f / clk_tck
    cpu.softirq = stat[7].to_f / clk_tck
    cpu.steal = stat[8].to_f  / clk_tck unless stat[8].nil?
    cpu.guest = stat[9].to_f / clk_tck unless stat[9].nil?
    cpu.guest_nice = stat[10].to_f / clk_tck unless stat[10].nil?
    cpu
  end

  def self.calculate_cpu_percent(start, last)
    start_sum = 0
    start.marshal_dump.each_value {|value| start_sum += value}
    last_sum = 0
    last.marshal_dump.each_value {|value| last_sum += value}

    start_busy = start_sum - start.idle
    last_busy = last_sum - last.idle

    # be aware of float precision issue
    return 0 if last_busy < start_busy
    busy_delta = last_busy - start_busy
    all_delta = last_sum - start_sum
    # if the interval is too small
    if busy_delta == 0
      percent = (last_busy + start_busy) / (last_sum + start_sum) * 100
    else
      percent = (busy_delta / all_delta) * 100
    end
    return percent.round(2)
  end

  def self.calculate_cpu_percent_field(start, last)
    start_sum = 0
    start.marshal_dump.each_value {|value| start_sum += value}
    last_sum = 0
    last.marshal_dump.each_value {|value| last_sum += value}

    ret = OpenStruct.new
    [:user, :nice, :system, :idle, :iowait, :irq, 
              :softirq, :steal, :guest, :guest_nice].each do |field|
      start_field = start[field]
      last_field = last[field]
      # be aware of float precision issue
      last_field = start_field if last_field < start_field
      field_delta = last_field - start_field
      all_delta = last_sum - start_sum
      # if the interval is too small
      if all_delta == 0
        percent = 0
      else
        percent = field_delta * 100 / all_delta
      end
      ret[field] = percent.round(2)
    end

    ret
  end

  private_class_method :get_cpu_fields, :calculate_cpu_percent

  @last_cpu_times = cpu_times()
  @last_per_cpu_times = cpu_times(true)
  @last_cpu_times_fields = cpu_times()
  @last_per_cpu_times_fields = cpu_times(true)

end

module Memory

  def self.virtual_memory()
    meminfo = OpenStruct.new
    IO.readlines('/proc/meminfo').each do |line|
      pair = line.split(':')
      case pair[0]
        when 'Cached'
          # values are expressed in KB, we want bytes instead
          meminfo.cached = pair[1].to_i * 1024
        when 'Active'
          meminfo.active = pair[1].to_i * 1024
        when 'Inactive'
          meminfo.inactive = pair[1].to_i * 1024
        when 'Buffers'
          meminfo.buffers = pair[1].to_i * 1024
        when 'MemFree'
          meminfo.free = pair[1].to_i * 1024
        when 'MemTotal'
          meminfo.total = pair[1].to_i * 1024
      end
    end

    meminfo.used = meminfo.total - meminfo.free
    meminfo.available = meminfo.free + meminfo.cached + meminfo.buffers
    meminfo.percent = COMMON::usage_percent((
      meminfo.total - meminfo.available) , meminfo.total, 1)
    meminfo
  end

  def self.swap_memory()
    meminfo = OpenStruct.new
    swaps = File.new('/proc/swaps')
    swaps.readline() # ignore column header
    _, _, total, used, _ = swaps.readline().split(" ")
    # values are expressed in 4 KB, we want bytes instead
    meminfo.total = total.to_i * 1024
    meminfo.used = used.to_i * 1024

    
    meminfo.free = meminfo.total - meminfo.used
    meminfo.percent = COMMON::usage_percent(meminfo.used, meminfo.total, 1)
    
    IO.readlines('/proc/vmstat').each do |line|
      # values are expressed in 4 KB, we want bytes instead
      if line.start_with?('pswpin')
        meminfo.sin = line.split(' ')[1].to_i * 4 * 1024
      elsif line.start_with?('pswpout')
        meminfo.sout = line.split(' ')[1].to_i * 4 * 1024
      end
    end

    meminfo
  end

end

module Disks

  def self.disk_parititions()
    
  end

  def self.disk_usage(path)
  end
   
end

module Network
  
end

module System
   
end

module Processes
   
end

