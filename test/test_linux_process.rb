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
    assert_equal Process.times.utime, @process.cpu_times().user
    assert_equal Process.times.stime, @process.cpu_times().system
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
    assert_respond_to @process.io_counters(), :rcount
    assert_respond_to @process.io_counters(), :wcount
    assert_respond_to @process.io_counters(), :rbytes
    assert_respond_to @process.io_counters(), :wbytes
  end

  def test_name
    # current process
    assert_equal true, @process.name().start_with?('ruby')
  end

  def test_nice
    @process.nice
  end

  def test_num_ctx_switches
    assert_respond_to @process.num_ctx_switches, :voluntary
    assert_respond_to @process.num_ctx_switches, :involuntary
  end

  def test_num_fds
    @process.num_fds
  end

  def test_num_threads
    # the result is different from Thread.list.size, because
    # it shows the number of threads in system size instead of ruby size
    @process.num_threads
  end

  def test_status
    assert_equal 'running', @process.status()
  end

  def test_terminal
    tty = @process.terminal()
    assert_equal true, tty.start_with?('/dev/tty') || tty.start_with?('/dev/pts/')
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
