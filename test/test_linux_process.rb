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
    @process.cpu_times()
  end

  def test_exe
    assert_equal true, @process.exe().start_with?("/usr/bin/ruby")
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

  def test_terminal
    tty = @process.terminal()
    assert_equal true, tty.start_with?('/dev/tty') || tty.start_with?('/dev/pts/')
  end

  def test_cpu_times
    assert_respond_to @process.cpu_times(), :user
    assert_respond_to @process.cpu_times(), :system
  end
end

class TestLinuxProcessErrorHandler < MiniTest::Test
  def test_no_such_process
    begin
      PlatformSpecificProcess.new(99999).name()
    rescue NoSuchProcess
    end
  end 

  def test_premission_denied
    #PlatformSpecificProcess.new(1).name()
  end

  def test_exe_access_denied
    begin
      PlatformSpecificProcess.new(1).exe()
    rescue AccessDenied
    end
  end

  def test_exe_no_such_process
    begin
      PlatformSpecificProcess.new(99999).exe()
    rescue NoSuchProcess
    end
  end
end
