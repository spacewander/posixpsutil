#ifndef COMMON_H
#define COMMON_H

long get_clock_ticks();
long get_page_size();
int get_priority(long pid, int *priority);
int set_priority(long pid, int priority);

#endif /* COMMON_H */
