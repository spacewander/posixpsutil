#ifndef LINUX_H
#define LINUX_H

int get_cpu_affinity(long pid, long **cpu_affinity, int *cpu_count);
int set_cpu_affinity(long pid, long *cpu_affinity, int seq_len);
int get_ionice(long pid, int *ioclass, int *iodata);
int set_ionice(long pid, int ioclass, int iodata);
int get_rlimit(long pid, int resource, long long *soft, long long *hard);
int set_rlimit(long pid, int resource, long long soft, long long hard);

int disk_usage(const char *path, unsigned long *frsize, unsigned long *blocks, 
        unsigned long *bavail, unsigned long *bfree);
int get_user(char *username, char *tty, char *hostname, 
        int *tstamp, short/* bool */ *user_proc);
#endif /* LINUX_H */
