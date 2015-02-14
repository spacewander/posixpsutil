#ifndef _GNU_SOURCE
    #define _GNU_SOURCE     1 /* See feature_test_macros(7) */
#endif

#include <errno.h>
#include <limits.h>
#include <sched.h>
#include <stdlib.h>

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
