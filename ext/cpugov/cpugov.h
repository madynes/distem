#ifndef _CPUGOV_H
#define _CPUGOV_H

#define STRBUFF_SIZE 128

#define DEFAULT_PITCH 0.1f /* default pitch (in seconds) */
#define MAX_CORES 128
#define CGROUP_FREEZE "FREEZE"
#define CGROUP_THAW "THAWED"

extern int cores[];
extern unsigned int corenb;
extern int freq_max;

#endif
