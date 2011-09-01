#ifndef _MAIN_H
#define _MAIN_H

	typedef struct {
		int cpu;
		float ratio;
	} cpu_ratio;

	typedef struct {
		int cpufreq;
		long long int interval;
		cpu_ratio* ratios;
		int cpus;
	} cpu_cmds;

	int run(cpu_cmds* cmds);

#endif
