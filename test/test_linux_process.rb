require 'minitest/autorun'
require 'posixpsutil/linux_process'

class TestLinuxProcess < MiniTest::Test
  def setup
    @process = PlatformSpecificProcess.new(Process.pid)
  end

  def test_cmdline
    # should be run with `rake test`
    assert_equal '-Ilib:lib:test', @process.cmdline()[1]
  end

  def test_cpu_times
    cpu_times = @process.cpu_times
    assert_equal Process.times.utime, cpu_times.user
    assert_equal Process.times.stime, cpu_times.system
  end

  def test_create_time
    assert_equal true, @process.create_time() < Time.now.to_f
  end

  def test_cwd
    assert_equal Dir.pwd, @process.cwd()
  end

  def test_exe
    assert_equal true, @process.exe().start_with?("/usr/bin/ruby")
  end

  def test_gids
    gids = @process.gids
    assert_equal Process::GID.rid, gids.real
    assert_equal Process::GID.eid, gids.effective
    assert_respond_to gids, :saved
  end

  def test_io_counters
    # r means read while w means write
    io_counters = @process.io_counters
    assert_respond_to io_counters, :rcount
    assert_respond_to io_counters, :wcount
    assert_respond_to io_counters, :rbytes
    assert_respond_to io_counters, :wbytes
  end

  def test_memory_info
    memory_info = @process.memory_info
    # Virtual Memory Size
    assert_respond_to memory_info, :vms
    # Resident Set Size
    assert_respond_to memory_info, :rss
  end

  def test_memory_info_ex
    memory_info_ex = @process.memory_info_ex
    assert_respond_to memory_info_ex, :shared
    assert_respond_to memory_info_ex, :text
    assert_respond_to memory_info_ex, :lib
    assert_respond_to memory_info_ex, :data
    assert_respond_to memory_info_ex, :dirty
    memory_info = @process.memory_info
    assert_equal memory_info.vms, memory_info_ex.vms
    assert_equal memory_info.rss, memory_info_ex.rss
  end

  def test_name
    # current process
    assert_equal true, @process.name().start_with?('ruby')
  end

  def test_nice
    @process.nice
  end

  def test_num_ctx_switches
    num_ctx_switches = @process.num_ctx_switches
    assert_respond_to num_ctx_switches, :voluntary
    assert_respond_to num_ctx_switches, :involuntary
  end

  def test_num_fds
    @process.num_fds
  end

  def test_num_threads
    # the result is different from Thread.list.size, because
    # it shows the number of threads in system size instead of ruby size
    @process.num_threads
  end

  def test_ppid
    assert_equal Process.ppid, @process.ppid
  end

  def test_status
    assert_equal 'running', @process.status()
  end

  def test_terminal
    tty = @process.terminal()
    assert_equal true, tty.start_with?('/dev/tty') || tty.start_with?('/dev/pts/')
  end

  def test_threads
    threads = @process.threads
    assert_equal @process.num_threads, @process.threads.size
    assert_respond_to threads.first, :thread_id
    assert_respond_to threads.first, :user_time
    assert_respond_to threads.first, :system_time
  end

  def test_uids
    uids = @process.uids
    assert_equal Process::UID.rid, uids.real
    assert_equal Process::UID.eid, uids.effective
    assert_respond_to uids, :saved
  end

end

class TestLinuxProcessErrorHandler < MiniTest::Test
  def test_no_such_process
    assert_raises NoSuchProcess do
      PlatformSpecificProcess.new(99999).name()
    end
  end 

  def test_premission_denied
    #PlatformSpecificProcess.new(1).name()
  end

  def test_exe_access_denied
    assert_raises AccessDenied do
      PlatformSpecificProcess.new(1).exe()
    end
  end

  def test_exe_no_such_process
    assert_raises NoSuchProcess do
      PlatformSpecificProcess.new(99999).exe()
    end
  end

end

class TestLinuxProcessClassMethods < MiniTest::Test
  def test_pids
    pids = PlatformSpecificProcess.pids
    assert_equal true, pids.include?(1)
    assert_equal true, pids.include?(Process.pid)
  end

end
