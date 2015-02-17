#ifndef LINUX_H
#define LINUX_H

int get_cpu_affinity(long pid, long **cpu_affinity, int *cpu_count);
int set_cpu_affinity(long pid, long *cpu_affinity, int seq_len);
int get_ionice(long pid, int *ioclass, int *iodata);
int set_ionice(long pid, int ioclass, int iodata);
int get_rlimit(long pid, int resource, long long *soft, long long *hard);
int set_rlimit(long pid, int resource, long long soft, long long hard);

#endif /* LINUX_H */
