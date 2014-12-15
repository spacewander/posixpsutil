require 'minitest/autorun'
require 'posixpsutil/linux_process'

class TestLinuxProcess < MiniTest::Test
  def setup
    @process = PlatformSpecificProcess.new(Process.pid)
  end

  def test_name
    # current process
    assert_equal true, @process.name().start_with?('ruby')
  end

  def test_cmdline
    # should be run with `rake test`
    assert_equal '-Ilib:lib:test', @process.cmdline()[1]
  end
end

class TestLinuxProcessErrorHandler < MiniTest::Test
  def test_no_such_file
    begin
      PlatformSpecificProcess.new(99999).name()
    rescue NoSuchProcess
    end
  end 

  def test_premission_denied
    #PlatformSpecificProcess.new(1).name()
  end
end
