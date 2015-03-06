# posixpsutil

Now posixpsuti is **only** available on Linux.
Because I don't have chance to access other posix platforms, I can't test the C extensions on them. I am sorry that I can't finish this project currently.

To make posixpsutil available on your platform, you can:

1. Fork this repo.
2. Check out [psutil](https://github.com/giampaolo/psutil), and open `./psutil`, look at the C part(`arch/*, *.c, *.h`).
3. Extract the Python's C extensions into pure C functions.
4. Posixpsutil uses [ffi](https://github.com/ffi/ffi) to call C extensions, so we need to modify `ext/Makefile`, compile the C part into a separate dynamic library(.so). By reading the Makefile, you can follow what I do on Linux.
5. Fulfill methods below in `lib/posixpsutil/$yourplatform/process.rb`:
  * cmdline
  * connections
  * cpu_affinity
  * cpu_affinity=
  * cpu_times
  * create_time
  * cwd
  * exe
  * gids
  * memory_info
  * memory_info_ex
  * memory_maps
  * name
  * nice
  * nice=
  * num_ctx_switches
  * num_fds
  * num_threads
  * open_files
  * pmmap_ext
  * pmmap_grouped
  * ppid
  * status
  * terminal
  * threads
  * time_used
  * uids
6. Implement `lib/posixpsutil/$yourplatform/system.rb`.
7. Don't forget to add tests!

## Features

Posixpsutil supports most API of [psutil](https://github.com/giampaolo/psutil). 

Posixpsutil can do what psutil can do in Ruby way, for example, **monitoring running processes** and **gain information of system utilization** (CPU, memory, disks, network). You can use it on **system monitoring**, **profiling and limiting process resources** and **management of running processes**, without the dependency on some commandline tools like ps/netstat/who...

You can read the docs to find more: http://spacewander.github.io/posixpsutil/

## Example

Do the same as the psutil:

```
~ pry
pry(main)> require 'posixpsutil'
```

### CPU

```
pry(main)> cpu = PosixPsutil::CPU
=> PosixPsutil::CPU

pry(main)> cpu.cpu_times
=> #<OpenStruct user=3215.5, nice=25.61, system=860.89, idle=19493.07, iowait=626.71, irq=0.04, softirq=14.68, steal=0.0, guest=0.0, guest_nice=0.0>

pry(main)> 3.times { p cpu.cpu_percent(1) }
17.44
15.54
18.59
=> 3

pry(main)> 3.times { p cpu.cpu_percent(1, true) }
[13.68, 12.5]
[19.19, 14.43]
[22.22, 9.68]
=> 3

pry(main)> 3.times { p cpu.cpu_times_percent(1, true) }
[#<OpenStruct user=8.33, nice=0.0, system=2.08, idle=86.46, iowait=3.13, irq=0.0, softirq=0.0, steal=0.0, guest=0.0, guest_nice=0.0>, #<OpenStruct user=10.64, nice=0.0, system=4.26, idle=85.11, iowait=0.0, irq=0.0, softirq=0.0, steal=0.0, guest=0.0, guest_nice=0.0>]
[#<OpenStruct user=12.12, nice=0.0, system=2.02, idle=85.86, iowait=0.0, irq=0.0, softirq=0.0, steal=0.0, guest=0.0, guest_nice=0.0>, #<OpenStruct user=11.22, nice=0.0, system=4.08, idle=84.69, iowait=0.0, irq=0.0, softirq=0.0, steal=0.0, guest=0.0, guest_nice=0.0>]
[#<OpenStruct user=9.47, nice=0.0, system=4.21, idle=82.11, iowait=4.21, irq=0.0, softirq=0.0, steal=0.0, guest=0.0, guest_nice=0.0>, #<OpenStruct user=7.45, nice=0.0, system=4.26, idle=88.3, iowait=0.0, irq=0.0, softirq=0.0, steal=0.0, guest=0.0, guest_nice=0.0>]
=> 3

pry(main)> 3.times { p cpu.cpu_times_percent(1, false) }
#<OpenStruct user=4.55, nice=0.0, system=2.53, idle=92.93, iowait=0.0, irq=0.0, softirq=0.0, steal=0.0, guest=0.0, guest_nice=0.0>
#<OpenStruct user=4.04, nice=0.0, system=3.03, idle=90.4, iowait=2.53, irq=0.0, softirq=0.0, steal=0.0, guest=0.0, guest_nice=0.0>
#<OpenStruct user=3.59, nice=0.0, system=2.05, idle=94.36, iowait=0.0, irq=0.0, softirq=0.0, steal=0.0, guest=0.0, guest_nice=0.0>
=> 3

pry(main)> cpu.cpu_count()
=> 2

pry(main)> cpu.cpu_count(false)
=> 2
```

### Memory

```
pry(main)> mem = PosixPsutil::Memory
=> PosixPsutil::Memory

pry(main)> mem.virtual_memory
=> #<OpenStruct total=3504287744, free=165306368, buffers=91377664, cached=1166606336, active=1884753920, inactive=1051353088, used=3338981376, available=1423290368, percent=59.4>

pry(main)> mem.swap_memory
=> #<OpenStruct total=4094685184, used=589824, free=4094095360, percent=0.0, sin=0, sout=589824>
```

### Disks

```
pry(main)> disks = PosixPsutil::Disks
=> PosixPsutil::Disks

pry(main)> disks.disk_partitions
=> [#<OpenStruct device="/dev/disk/by-uuid/03ae1c66-67b9-4b2b-841a-e8b12a57952d", mountpoint="/", fstype="ext4", opts="rw,relatime,errors=remount-ro,data=ordered">,
 #<OpenStruct device="/dev/sda11", mountpoint="/home", fstype="ext4", opts="rw,relatime,data=ordered">,
 #<OpenStruct device="/dev/sda8", mountpoint="/boot", fstype="ext4", opts="rw,relatime,data=ordered">]

pry(main)> disks.disk_usage('/')
=> #<OpenStruct free=36572086272, total=75917107200, used=35465027584, percent=46.7>

pry(main)> disks.disk_io_counters(false)
=> #<OpenStruct read_bytes=1463378944, write_bytes=1621193728, read_count=67241, write_count=59548, read_time=2429472, write_time=1767508>
```

### Network

```
pry(main)> net = PosixPsutil::Network
=> PosixPsutil::Network

pry(main)> net.net_io_counters(true)
=> {:eth0=>
  #<OpenStruct bytes_recv=204395117, packets_recv=620506, errin=0, dropin=239, bytes_sent=13377217, packets_sent=120052, errout=0, dropout=0>,
 :lo=>
  #<OpenStruct bytes_recv=6711764, packets_recv=11627, errin=0, dropin=0, bytes_sent=6711764, packets_sent=11627, errout=0, dropout=0>,
 :wlan0=>
  #<OpenStruct bytes_recv=0, packets_recv=0, errin=0, dropin=0, bytes_sent=0, packets_sent=0, errout=0, dropout=0>}
  
pry(main)> net.net_connections
=> [#<OpenStruct inode=10029, laddr=["127.0.0.1", 5432], raddr=[], family=2, type=1, status="LISTEN", pid=nil, fd=-1>,
 #<OpenStruct inode=11846, laddr=["127.0.0.1", 5433], raddr=[], family=2, type=1, status="LISTEN", pid=nil, fd=-1>,
 #<OpenStruct inode=209070, laddr=["127.0.0.1", 33264], raddr=[], family=2, type=1, status="LISTEN", pid=7770, fd=7>,
 #<OpenStruct inode=0, laddr=["127.0.0.1", 33264], raddr=["127.0.0.1", 37997], family=2, type=1, status="FIN_WAIT2", pid=nil, fd=-1>,
 #<OpenStruct inode=9897, laddr=["::", 22], raddr=[], family=10, type=1, status="LISTEN", pid=nil, fd=-1>,
 #<OpenStruct inode=16946, laddr=["::1", 631], raddr=[], family=10, type=1, status="LISTEN", pid=nil, fd=-1>,
...
```

### Other system info

```
pry(main)> sys = PosixPsutil::System
=> PosixPsutil::System

pry(main)> sys.users
=> [#<OpenStruct name="lzx", terminal=":0", host="localhost", started=1425628286>,
 #<OpenStruct name="lzx", terminal="pts/9", host="localhost", started=1425628304>,
 #<OpenStruct name="lzx", terminal="pts/14", host="localhost", started=1425630105>,
 #<OpenStruct name="lzx", terminal="pts/15", host="localhost", started=1425641274>,
 #<OpenStruct name="lzx", terminal="pts/0", host="localhost", started=1425640736>]
 
pry(main)> sys.boot_time
=> 1425628224.0
```

### Process management
```
pry(main)> PosixPsutil::Process.pids
=> [1,
 2,
 3,
 5,
...

pry(main)> p = PosixPsutil::Process.new 3205
=> "(pid=3205, name=chrome)"

pry(main)> p.name
=> "chrome"

pry(main)> p.exe
=> "/opt/google/chrome/chrome"

pry(main)> p.cwd
=> "/home/lzx"

pry(main)> p.cmdline
=> ["/opt/google/chrome/chrome "]

pry(main)> p.status
=> "sleeping"

pry(main)> p.username
=> "lzx"

pry(main)> p.create_time
=> 1425628535.4

pry(main)> p.terminal
=> nil

pry(main)> p.uids
=> #<OpenStruct real=1000, effective=1000, saved=1000>

pry(main)> p.gids
=> #<OpenStruct real=1000, effective=1000, saved=1000>

pry(main)> p.cpu_times
=> #<OpenStruct user=548.71, system=205.22>

pry(main)> p.cpu_percent(1.0)
=> 2.0

pry(main)> p.cpu_affinity
=> [0, 1]

pry(main)> p.cpu_affinity([1]) # set
=> [1]

pry(main)> p.cpu_affinity([1])
=> [1]

pry(main)> p.memory_percent
=> 7.19

pry(main)> p.memory_info
=> #<OpenStruct vms=1918775296, rss=252518400>

pry(main)> p.memory_info_ex
=> #<OpenStruct vms=1918775296, rss=252571648, shared=97820672, text=84987904, lib=0, data=1106513920, dirty=0>

pry(main)> p.memory_maps[0..4]
=> [#<OpenStruct path="[anon]", rss=146399232, size=770793472, pss=146399232, shared_clean=0, shared_dirty=0, private_clean=0, private_dirty=146399232, referenced=137666560, anonymous=146399232, swap=0>,
 #<OpenStruct path="/run/shm/.com.google.Chrome.0gYFZE (deleted)", rss=262144, size=262144, pss=131072, shared_clean=0, shared_dirty=262144, private_clean=0, private_dirty=0, referenced=262144, anonymous=0, swap=0>,
 #<OpenStruct path="/run/shm/.com.google.Chrome.09FFTD (deleted)", rss=262144, size=262144, pss=131072, shared_clean=0, shared_dirty=262144, private_clean=0, private_dirty=0, referenced=262144, anonymous=0, swap=0>,
 #<OpenStruct path="/run/shm/.com.google.Chrome.VdqINC (deleted)", rss=262144, size=262144, pss=131072, shared_clean=0, shared_dirty=262144, private_clean=0, private_dirty=0, referenced=262144, anonymous=0, swap=0>,
 #<OpenStruct path="/run/shm/.com.google.Chrome.o2jPHB (deleted)", rss=262144, size=262144, pss=131072, shared_clean=0, shared_dirty=262144, private_clean=0, private_dirty=0, referenced=262144, anonymous=0, swap=0>]
 
pry(main)> p.io_counters
=> #<OpenStruct rcount="6569081", wcount="8856376", rbytes="244678656", wbytes="587444224">

pry(main)> p.open_files
=> [#<OpenStruct path="/opt/google/chrome/icudtl.dat", fd=3>,
 #<OpenStruct path="/opt/google/chrome/chrome_100_percent.pak", fd=34>,
 #<OpenStruct path="/opt/google/chrome/locales/zh-CN.pak", fd=35>,
 #<OpenStruct path="/opt/google/chrome/resources.pak", fd=36>,
 #<OpenStruct path="/home/lzx/.pki/nssdb/cert9.db", fd=37>,
 #<OpenStruct path="/home/lzx/.pki/nssdb/key4.db", fd=38>,
 ...
 
pry(main)> p.connections
=> [#<OpenStruct inode=232444, laddr=["110.64.91.97", 36656], raddr=["74.125.235.224", 443], family=2, type=1, status="SYN_SENT", fd=91>,
 #<OpenStruct inode=94371, laddr=["110.64.91.97", 58733], raddr=["64.233.189.188", 443], family=2, type=1, status="ESTABLISHED", fd=253>,
 #<OpenStruct inode=234684, laddr=["110.64.91.97", 51084], raddr=["74.125.203.84", 443], family=2, type=1, status="SYN_SENT", fd=198>,
 #<OpenStruct inode=234513, laddr=["110.64.91.97", 42231], raddr=["74.125.235.228", 443], family=2, type=1, status="SYN_SENT", fd=114>,
 #<OpenStruct inode=235594, laddr=["110.64.91.97", 51241], raddr=["74.125.235.227", 443], family=2, type=1, status="SYN_SENT", fd=286>,
 #<OpenStruct inode=234776, laddr=["110.64.91.97", 51240], raddr=["74.125.235.227", 443], family=2, type=1, status="SYN_SENT", fd=238>,
 #<OpenStruct inode=201094, laddr=["110.64.91.97", 54501], raddr=["192.30.252.91", 443], family=2, type=1, status="ESTABLISHED", fd=61>,
 #<OpenStruct inode=234680, laddr=["110.64.91.97", 51083], raddr=["74.125.203.84", 443], family=2, type=1, status="SYN_SENT", fd=121>,
 #<OpenStruct inode=20200, laddr=["0.0.0.0", 5353], raddr=[], family=2, type=2, status="NONE", fd=169>]

pry(main)> p.num_threads
=> 42

pry(main)> p.num_fds
=> 388

pry(main)> p.threads[0..2]
=> [#<OpenStruct thread_id="3205", user_time=394.05, system_time=101.4>,
 #<OpenStruct thread_id="3217", user_time=11.43, system_time=0.74>,
 #<OpenStruct thread_id="3229", user_time=0.0, system_time=0.0>]

pry(main)> p.num_ctx_switches
=> #<OpenStruct voluntary=1156615, involuntary=1213426>

pry(main)> p.nice
=> 0

pry(main)> p.nice=10
=> 10

pry(main)> p.rlimit(:nofile, {:soft => 5, :hard => 5})
=> {:soft=>5, :hard=>5}

pry(main)> p.rlimit :nofile
=> {:soft=>5, :hard=>5}

pry(main)> p.suspend
=> 1

pry(main)> p.resume
=> 1

pry(main)> p.terminate
=> 1

pry(main)> p = PosixPsutil::Process.new 9619
=> "(pid=9619, name=chrome)"
pry(main)> p.wait(3)
Timeout::Error: when waiting for (pid=9619)
from /var/lib/gems/2.1.0/gems/posixpsutil-0.1.0/lib/posixpsutil/common.rb:128:in `check_timeout'
```

## Install

```
[sudo] gem install posixpsutil
# or
git clone https://github.com/spacewander/posixpsutil
gem build posixpsutil.gemspec && [sudo] gem install --local posixpsutil
```
