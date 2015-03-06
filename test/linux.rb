require 'time'
require 'posixpsutil'

# bytes tolerance for OS memory related tests
TOLERANCE = 500 * 1024 # 500KB

include PosixPsutil

class TestCPU < MiniTest::Test
  CPU.cpu_count
  CPU.cpu_count(false)
  CPU.cpu_times
  CPU.cpu_times(true)
  CPU.cpu_percent(1.0)
  CPU.cpu_percent(1.0, true)
  CPU.cpu_times_percent(1.0, true)
  CPU.cpu_times_percent(1.0, false)
end

class TestDisks < MiniTest::Test
  def test_disk_usage
    usage = Disks.disk_usage('/')
    IO.popen('df') do |f|
      f.readlines[1..-1].each do |fs|
        _, total, used, free, _, mountpoint = fs.split(' ')
        if mountpoint == '/'
          assert_equal usage.total, total.to_i * 1024
          assert_equal usage.used, used.to_i * 1024
          assert_equal usage.free, free.to_i * 1024
        end
      end
    end
  end

  def test_disk_io_counters
    Disks.disk_io_counters(false) # total
    Disks.disk_io_counters # perdisk
  end 

  def test_disk_partitions
    assert_respond_to Disks.disk_partitions[0], :fstype
    assert_respond_to Disks.disk_partitions[0], :device
    assert_respond_to Disks.disk_partitions[0], :mountpoint
    assert_respond_to Disks.disk_partitions[0], :opts
  end
end

class TestMemory < MiniTest::Test
   def test_vmem_total
     IO.popen('free') do |f|
       f.readline
       total = f.readline.split[1].to_i * 1024
       assert_equal total, Memory.virtual_memory.total
     end
   end

   def test_vmem_used
     IO.popen('free') do |f|
       f.readline
       used = f.readline.split[2].to_i * 1024
       assert_in_delta used, Memory.virtual_memory.used, TOLERANCE
     end
   end

   def test_vmem_free
     IO.popen('free') do |f|
       f.readline
       free = f.readline.split[3].to_i * 1024
       assert_in_delta free, Memory.virtual_memory.free, TOLERANCE
     end
   end

   def test_vmem_buffers
     IO.popen('free') do |f|
       f.readline
       buffers = f.readline.split[5].to_i * 1024
       assert_in_delta buffers, Memory.virtual_memory.buffers, TOLERANCE
     end
   end

   def test_vmem_cached
     IO.popen('free') do |f|
       f.readline
       cached = f.readline.split[6].to_i * 1024
       assert_in_delta cached, Memory.virtual_memory.cached, TOLERANCE
     end
   end

   def test_swapmem_total
     IO.popen('free') do |f|
       total = f.readlines[3].split[1].to_i * 1024
       assert_in_delta total, Memory.swap_memory.total, TOLERANCE
     end
   end

   def test_swapmem_used
     IO.popen('free') do |f|
       used = f.readlines[3].split[2].to_i * 1024
       assert_in_delta used, Memory.swap_memory.used, TOLERANCE
     end
   end

   def test_swapmem_free
     IO.popen('free') do |f|
       free = f.readlines[3].split[3].to_i * 1024
       assert_in_delta free, Memory.swap_memory.free, TOLERANCE
     end
   end

end

class TestSystem < MiniTest::Test
  def test_bool_time
    date, time = IO.popen('who -b').readline.split[1..2]
    # the result of `who -b` accurates to the minute
    assert_in_delta DateTime.parse(date + " " + time).to_time.to_f, 
      System.boot_time, 60 * 1000
  end
   
  def test_users
    users = []
    IO.popen('who') do |f|
      f.readlines.each do |login_info|
        name, tty, date, time, host = login_info.split(' ')
        host = host[1..-2]
        host = 'localhost' if host == ':0'
        ts = Time.parse(date + " " + time).to_i
        # the started given by who is accurates
        users.push(OpenStruct.new({name: name, terminal: tty, 
                                   host: host, started: ts}))
      end
    end
    sys_users = System.users
    equal = true
    users.each_index do |i|
      time_equal = users[i].started - 100 < sys_users[i].started && 
          sys_users[i].started < users[i].started + 100
      unless time_equal && users[i].name == sys_users[i].name && 
          users[i].terminal == sys_users[i].terminal && 
          users[i].host == sys_users[i].host
        equal = false
        break
      end
    end
    assert equal
  end
end

class TestNetwork < MiniTest::Test
  def test_net_io_counters
    netio = Network.net_io_counters(true)[:lo]
    assert_respond_to netio, :bytes_sent
    assert_respond_to netio, :bytes_recv
    assert_respond_to netio, :packets_sent
    assert_respond_to netio, :packets_recv
    assert_respond_to netio, :errin
    assert_respond_to netio, :errout
    assert_respond_to netio, :dropin
    assert_respond_to netio, :dropout
  end

  def test_net_connetions
    conn = Network.net_connections[0]
    assert_respond_to conn, :inode
    assert_respond_to conn, :fd
    assert_respond_to conn, :family
    assert_respond_to conn, :type
    assert_respond_to conn, :laddr
    assert_respond_to conn, :raddr
    assert_respond_to conn, :status
    assert_respond_to conn, :pid
  end
end
