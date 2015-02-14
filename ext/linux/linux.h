#ifndef LINUX_H
#define LINUX_H

int get_cpu_affinity(long pid, long **cpu_affinity, int *cpu_count);
int set_cpu_affinity(long pid, long *cpu_affinity, int seq_len);

#endif /* LINUX_H */
