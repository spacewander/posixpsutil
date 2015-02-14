#ifndef LINUX_H
#define LINUX_H

int get_cpu_affinity(long pid, long **cpu_affinity, int *cpu_count);

#endif /* LINUX_H */
