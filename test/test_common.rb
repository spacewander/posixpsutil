require 'minitest/autorun'
require 'posixpsutil/common'

include PosixPsutil

class TestPOSIX < MiniTest::Test
  include POSIX

  def test_pid_exists
    assert_equal true, pid_exists(1)
    assert_equal true, pid_exists(Process.pid)
    assert_equal false, pid_exists(99999)
  end

  def test_wait_pid_child_exit_by_exit
    pid = fork do
      sleep 0.05
      exit 1
    end
    assert_equal 1, wait_pid(pid)
  end

  def test_wait_pid_child_exit_by_signal
    pid = fork do
      sleep 0.05
    end
    Process.kill(9, pid)
    assert_equal 9, wait_pid(pid)
  end

  def test_wait_pid_child_timeout
    pid = fork do
      sleep 0.05
    end
    assert_raises Timeout::Error do
      wait_pid(pid, 0.02)
    end
  end

  def test_wait_pid_timeout
    assert_raises Timeout::Error do
      wait_pid(1, 0.02)
    end
  end
end
