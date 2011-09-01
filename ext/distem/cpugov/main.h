#ifndef _MAIN_H
#define _MAIN_H

int extrun(unsigned long long pitch, unsigned int freqlow, unsigned int freqhigh, double ratelow, char *cgroup_path);

#define CGROUP_FREEZE "FROZEN"
#define CGROUP_THAW "THAWED"

#endif
