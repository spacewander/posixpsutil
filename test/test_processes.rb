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
   end

   def test_no_such_process
      begin
        raise NoSuchProcess.new(pid:3000, name:"ruby")
      rescue NoSuchProcess => e
        assert_equal "process no longer exists (pid=3000, name=ruby)", 
          e.message
      end
   end
end

class TestProcesses < MiniTest::Test
end
