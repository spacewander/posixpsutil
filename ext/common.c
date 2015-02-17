#include <errno.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <unistd.h>

#include "common.h"

long get_clock_ticks()
{
    return sysconf(_SC_CLK_TCK);
}

long get_page_size()
{
    return sysconf(_SC_PAGE_SIZE);
}

int get_priority(long pid, int *priority)
{
    *priority = getpriority(PRIO_PROCESS, pid);
    return errno;
}

int set_priority(long pid, int priority)
{
    if (setpriority(PRIO_PROCESS, pid, priority) == -1) {
        return errno;
    }
    return 0;
}

