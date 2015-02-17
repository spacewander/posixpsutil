#ifndef _GNU_SOURCE
    #define _GNU_SOURCE     1 /* See feature_test_macros(7) */
#endif
#define _FILE_OFFSET_BITS 64

#include <errno.h>
#include <limits.h>
#include <sched.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <sys/syscall.h>
#include <time.h>
#include <unistd.h>

#include "./linux.h"

/* The minimum number of CPUs allocated in a cpu_set_t */
static const int NCPUS_START = sizeof(unsigned long) * CHAR_BIT; /* 8 * 8 */

/*
 * Return process CPU affinity
 * The dual implementation exists because of:
 * https://github.com/giampaolo/psutil/issues/536
 */

#ifdef CPU_ALLOC

/**
 * @param pid [in]
 * @param cpu_affinity [out] a list of cpu affinity
 * @param cpu_count [out] the length of list
 * @return 
 *   A status code indicates if the call is success or what went wrong:
 *
 *   0      : ok.
 *   -1     : got nothing (nil).
 *   ENOMEM : can't allocate memory for CPU set.
 *   EFAULT : A supplied memory address was invalid.
 *   ESRCH  : The thread whose ID is pid could not be found.
 *   other  : Other System call errors. 
 */
int get_cpu_affinity(long pid, long **cpu_affinity, int *cpu_count)
{
    if (pid < 0) {
        return -1;
    }
    int num_cpus;
    size_t setsize;
    cpu_set_t *mask = NULL;

    num_cpus = NCPUS_START;
    while (1) {
        setsize = CPU_ALLOC_SIZE(num_cpus);
        mask = CPU_ALLOC(num_cpus);
        if (mask == NULL) {
            return 12; /* Errno::ENOMEM */
        }
        if (sched_getaffinity(pid, setsize, mask) == 0) {
            break;
        }
        CPU_FREE(mask);
        /* EINVAL means no enough memory allocated for CPU set */
        if (errno != EINVAL) {
            return errno;
        }

        if (num_cpus > INT_MAX / 2) {
            return -1; /* could not allocate a large enough CPU set */
        }
        num_cpus = num_cpus * 2;
    }

    int cpucount_s = CPU_COUNT_S(setsize, mask);
    *cpu_affinity = (long *)malloc(cpucount_s * sizeof( long ));
    int cpu, count;
    for (cpu = 0, count = 0; count < cpucount_s; cpu++) {
        if (CPU_ISSET_S(cpu, setsize, mask)) {
            (*cpu_affinity)[count] = cpu;
            count++;
        }
    }
    CPU_FREE(mask);
    *cpu_count = cpucount_s;
    return 0;
}

#else

int get_cpu_affinity(long pid, long **cpu_affinity, int *cpu_count)
{
    if (pid < 0) {
        return -1;
    }
    cpu_set_t cpuset;

	CPU_ZERO(&cpuset);
    if (sched_getaffinity(pid, sizeof( cpu_set_t ), &cpuset) < 0) {
        return errno;
    }

    int i, count;
    int cpucount_s = CPU_COUNT(&cpuset);
    *cpu_affinity = (long *)malloc(cpucount_s * sizeof( long ));
    for (i = 0, count = 0; i < CPU_SETSIZE && count < cpucount_s; ++i) {
        if (CPU_ISSET(i, &cpuset)) {
            (*cpu_affinity)[count] = i;
            count++;
        }
    }
    *cpu_count = count;
    return 0;
}

#endif

/*
 * Set process CPU affinity; expects a bitmask
 * @param pid [in]
 * @param cpu_affinity [out] a list of cpu affinity you want to set with
 * @param seq_len [out] min(the length of list, the number of CPUs)
 * @return
 *   0      : ok.
 *   errno  : specific error code reported by sched_setaffinity, like ENOMEM
 */
int set_cpu_affinity(long pid, long *cpu_affinity, int seq_len)
{
    cpu_set_t cpu_set;
    int i;

    CPU_ZERO(&cpu_set);
    for (i = 0; i < seq_len; i++) {
        CPU_SET(cpu_affinity[i], &cpu_set);
    }

    if (sched_setaffinity(pid,  sizeof( cpu_set_t ), &cpu_set)) {
        return errno;
    }

    return 0;
}

/* find them in linux/ioprio.h */
enum {
    IOPRIO_WHO_PROCESS = 1,
    IOPRIO_WHO_PGRP,
    IOPRIO_WHO_USER,
};

#define IOPRIO_CLASS_SHIFT 13
#define IOPRIO_PRIO_MASK ((1UL << IOPRIO_CLASS_SHIFT) - 1)

#define IOPRIO_PRIO_CLASS(mask) ((mask) >> IOPRIO_CLASS_SHIFT)
#define IOPRIO_PRIO_DATA(mask) ((mask) & IOPRIO_PRIO_MASK)
#define IOPRIO_PRIO_VALUE(class, data) (((class) << IOPRIO_CLASS_SHIFT) | data)

/*
 * Return ioclass and iodata representing process I/O priority.
 * @return
 * 0    : ok.
 * else : the errno code indicates what went wrong
 */
int get_ionice(long pid, int *ioclass, int *iodata)
{
    int ioprio = syscall(__NR_ioprio_get, IOPRIO_WHO_PROCESS, pid);
    if (ioprio == -1) {
        return errno;
    }
    *ioclass = IOPRIO_PRIO_CLASS(ioprio);
    *iodata = IOPRIO_PRIO_DATA(ioprio);
    return 0;
}

/*
 * sets process I/O priority.
 * ioclass can be either IOPRIO_CLASS_RT, IOPRIO_CLASS_BE, IOPRIO_CLASS_IDLE
 * or 0. iodata goes from 0 to 7 depending on ioclass specified.
 * @return 0 for ok and other for errno code
 */
int set_ionice(long pid, int ioclass, int iodata)
{
    int ioprio = IOPRIO_PRIO_VALUE(ioclass, iodata);
    if (syscall(__NR_ioprio_set, IOPRIO_WHO_PROCESS, pid, ioprio) == -1) {
        return errno;
    }
    return 0;
}

/*
 * A wrapper around prlimit(2); gets process resource limits.
 * @param 'soft' for rlim_max
 * @param 'hard' for rlim_cur
 */
int get_rlimit(long pid, int resource, long long *soft, long long *hard)
{
    struct rlimit cur;
    if (prlimit(pid, resource, NULL, &cur) == -1) {
        return errno;
    }
    *soft = cur.rlim_cur;
    *hard = cur.rlim_max;
    return 0;
}

/*
 * A wrapper around prlimit(2); sets process resource limits.
 * @param 'soft' for rlim_max
 * @param 'hard' for rlim_cur
 */
int set_rlimit(long pid, int resource, long long soft, long long hard)
{
    struct rlimit before; 
    struct rlimit after;
    after.rlim_cur = soft;
    after.rlim_max = hard;
    if (prlimit(pid, resource, &after, &before) == -1) {
        return errno;
    }
    return 0;
}
