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
    @process = Processes.new()
  end

  def test_eq
    assert_equal @process, @process
  end
  
  def test_not_eq
    refute_equal Process.pid, @process
  end

  def test_to_s
    assert_equal "(pid=#{Process.pid}, name=#{@process.name()})", 
      @process.to_s
  end

  def test_to_hash
    hash = @process.to_hash([:status, :cwd])
    assert_equal 2, hash.keys.size
    assert_equal @process.status, hash[:status]
    assert_equal @process.cwd, hash[:cwd]
  end

  def test_to_hash
    default = {
      :root_dir => 'sleeping',
      :sleep => '/'
    }
    assert_raises NotImplementedError do
      @process.to_hash([:sleep, :root_dir], default)
    end
  end

  def test_to_hash_symbol_only
    assert_equal true, @process.to_hash(["exe", "cwd"]).empty?
  end

  def test_inspect
    assert_equal "(pid=#{Process.pid}, name=#{@process.name()})".inspect, 
      @process.inspect
  end

  def test_parent
    assert_equal Process.ppid, @process.parent.pid
  end

  def test_is_running
    assert_equal true, @process.is_running
  end

  def test_name
    # current process
    assert_equal true, @process.name().start_with?('ruby')
  end

  def test_cmdline
    # should be run with `rake test`
    assert_equal '-Ilib:lib:test', @process.cmdline()[1]
  end

  def test_exe
    assert_equal true, @process.exe().start_with?("/usr/bin/ruby")
  end

  def test_username
    @process.username()
  end

  def test_cpu_percent
    assert_equal 0.0, @process.cpu_percent # first called
    #10000.times { |i|  i ** 6}
    # your machine, err, may take less than 50 percent of cpu resource to
    # finish above process
    #assert_equal true, @process.cpu_percent > 50
    sleep 0.1
    last_proc_cpu_times = @process.instance_variable_get(:@last_proc_cpu_times)
    last_proc_cpu_times.user -= 0.1
    @process.instance_variable_set(:@last_proc_cpu_times, last_proc_cpu_times)
    # approximately 100
    assert_equal true, @process.cpu_percent > 50

    # test cpu_percent (blocking)
    start = Time.now
    @process.cpu_percent(0.1)
    stop = Time.now
    assert_in_delta 0.1, stop - start, 0.1
  end

  def test_children
    sh = @process.parent()
    assert_equal true, sh.children().include?(@process)
    children = sh.parent.children(true)
    assert_equal true, children.include?(@process)
    assert_equal true, children.include?(sh)
  end

  def test_memory_percent
    @process.memory_percent
    # total memory should be cached after first called
    refute_equal nil, Processes.class_variable_get(:@@total_phymem)
  end

  def test_memory_maps
    maps = @process.memory_maps
    no_groupby_maps = @process.memory_maps(false)
    assert_equal maps.size, maps.uniq.size
    assert_equal true, maps.size <= no_groupby_maps.size
    assert_equal true, maps[0].size >= no_groupby_maps[0].size
  end
end

class TestPlatformSpecificMethod < MiniTest::Test
  def test_has_io_counters
    has_method_defined = Processes.method_defined?('io_counters')
    os = RbConfig::CONFIG['host_os']
    if os =~ /linux/
      assert_equal true, has_method_defined
    else
      assert_equal false, has_method_defined
    end
  end 

  def test_has_ionice
    has_method_defined = Processes.method_defined?('ionice')
    os = RbConfig::CONFIG['host_os']
    if os =~ /linux|bsd/
      assert_equal true, has_method_defined
    else
      assert_equal false, has_method_defined
    end
  end

  if Processes.method_defined?('ionice')
    def test_ionice
      # TODO test when it completed
    end
  end

  def test_has_rlimit
    has_method_defined = Processes.method_defined?('rlimit')
    os = RbConfig::CONFIG['host_os']
    if os =~ /linux/
      assert_equal true, has_method_defined
    else
      assert_equal false, has_method_defined
    end
  end

  def test_has_cpu_affinity
    has_method_defined = Processes.method_defined?('cpu_affinity')
    os = RbConfig::CONFIG['host_os']
    if os =~ /linux/
      assert_equal true, has_method_defined
    else
      assert_equal false, has_method_defined
    end
  end

end

class TestProcessesClassMethods < MiniTest::Test

  def test_pid_exists
    assert_equal true, Processes.pid_exists(1)
  end

  def test_process_iter
    process_iter = Processes.process_iter
    assert_equal true, process_iter.include?(Processes.new(Process.pid))
    assert_equal true, process_iter.include?(Processes.new(1))
    # process_iter should cache processes in @@pmap
    pmap = Processes.class_variable_get(:@@pmap)
    assert_equal true, process_iter.size == pmap.size
  end 
end
