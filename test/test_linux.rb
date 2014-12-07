require 'minitest/autorun'
require 'posixpsutil'

# bytes tolerance for OS memory related tests
TOLERANCE = 500 * 1024 # 500KB

class TestCPU < MiniTest::Test
  CPU.cpu_count
  CPU.cpu_count(false)
  CPU.cpu_times
  CPU.cpu_times(true)
  CPU.cpu_percent(1.0)
  CPU.cpu_percent(1.0, true)
  CPU.cpu_times_percent(1.0, true)
end

class TestDisks < MiniTest::Test
  def test_disk_usage
    usage = Disks.disk_usage('/')
    IO.popen('df') do |f|
      f.readlines[1..-1].each do |fs|
        _, total, used, free, percent, mountpoint = fs.split(' ')
        if mountpoint == '/'
          assert_equal usage.total, total.to_i * 1024
          assert_equal usage.used, used.to_i * 1024
          assert_equal usage.free, free.to_i * 1024
          assert_equal usage.percent, percent
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
