require 'minitest/autorun'
require 'posixpsutil/processes'

class TestPsutilError < MiniTest::Test
   def test_access_denied
     begin
       raise AccessDenied.new(pid:3000, name:"ruby")
     rescue AccessDenied => e
       assert_equal "access is denied (pid=3000, name=ruby)", 
         e.message
     end
     begin
       raise AccessDenied.new
     rescue AccessDenied => e
       assert_equal "access is denied ", e.message
     end
   end

   def test_no_such_process
      begin
        raise NoSuchProcess.new(pid:3000, name:"ruby")
      rescue NoSuchProcess => e
        assert_equal "process no longer exists (pid=3000, name=ruby)", 
          e.message
      end
      begin
        raise NoSuchProcess.new(pid:3000)
      rescue NoSuchProcess => e
        assert_equal "process no longer exists (pid=3000)", e.message
      end
   end
end

class TestProcesses < MiniTest::Test

  def setup
    # if pid not given, the pid should be Process.pid
    @anonymous_process = Processes.new()
  end

  def test_eq
    assert_equal @anonymous_process, @anonymous_process
  end
  
  def test_not_eq
    refute_equal Process.pid, @anonymous_process
  end

  def test_to_s
    assert_equal "(pid=#{Process.pid}, name=#{@anonymous_process.name()})", 
      @anonymous_process.to_s
  end

  def test_inspect
    assert_equal "(pid=#{Process.pid}, name=#{@anonymous_process.name()})".inspect, 
      @anonymous_process.inspect
  end

end
