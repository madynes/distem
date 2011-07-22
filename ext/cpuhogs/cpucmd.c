
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <getopt.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>
#include <ctype.h>
#include "cpucmd.h"

static int get_cpufreq_max(int cpu) {
	int freq;
	FILE* f;
	char buf[1024];

	sprintf(buf, "/sys/devices/system/cpu/cpu%d/cpufreq/cpuinfo_max_freq", cpu);
	f = fopen(buf, "r");
	if (!f) {
		return -1;
	}
	if (fscanf(f, "%d", &freq) != 1) {
		freq = -1;
	}
	fclose(f);
	return freq;
}

static int get_procfs_max(int cpu) {
	FILE* f;
	ssize_t size;
	size_t n, ret = -1;
	char* buf = (char*)malloc(1024 * sizeof(char));

	if (!buf) {
		return -1;
	}

	f = fopen("/proc/cpuinfo", "r");
	if (!f) {
		return -1;
	}

	const char* field = "cpu MHz";
	const int len = strlen(field);
	while ( (size = getline(&buf, &n, f)) != -1) {
		if (strncmp(buf, field, len) == 0) {
			if (cpu == 0) {
				float freq;
				char* nbuf = buf; // omit field
				while(*nbuf && *nbuf != ':')
					nbuf++;
				if (sscanf(nbuf, ": %f", &freq) == 1) {
					ret = (int)(freq * 1e3);
				} // else ret = -1;
				break;
			} else {
				cpu--;
			}
		}
	}

	fclose(f);
	free(buf);

	return ret;
}

static int get_freq_max(int cpu, int cpufreq) {
	int ret;
	struct stat st;

	ret = stat("/sys/devices/system/cpu/cpu0/cpufreq", &st);

	if (ret == 0 && cpufreq) { // cpufreq on!
		return get_cpufreq_max(cpu);
	}

	if ( (ret == -1 && errno == ENOENT) || !cpufreq) {
		return get_procfs_max(cpu);
	}

	return -1;
}

cpu_cmds* parse_cpus(int argc, char** argv) {
	int opt;
	int i, j;
	long long int interval = 10000000;
	int cpufreq = 1;
	double fint;

	while ( (opt = getopt(argc, argv, "i:p")) != -1) {
		switch(opt) {
			case 'p':
				cpufreq = 0; break;
			case 'i':
				fint = strtod(optarg, NULL);
				interval = (long long int)(fint * 1e9); break;
			default:
				printf("Unknown cmd line arguments.\n");
				return 0;
		}
	}

	if (optind >= argc) {
		printf("Expected argument after options.\n");
		return 0;
	}

	int fields = argc - optind;

	void* mem = (cpu_cmds*)malloc(sizeof(cpu_cmds) + sizeof(cpu_ratio) * fields);
	if (!mem) {
		return 0;
	}
	cpu_cmds* cmds = (cpu_cmds*)mem;
	cmds->ratios = (cpu_ratio*)((char*)mem + sizeof(cpu_cmds));  /* c'est sioux! */

	cmds->cpus = fields;
	cmds->interval = interval;
	cmds->cpufreq = cpufreq;

	for (i=optind; i < argc; i++) {
		char* arg = argv[i];
		int* cpu = &cmds->ratios[i-optind].cpu;
		float* ratio = &cmds->ratios[i-optind].ratio;
		int len = strlen(arg);
		int ret, mfreq;
		
		if (arg[len - 1] == 'f') { // ratio 
			ret = sscanf(arg, "%d:%ff", cpu, ratio);
			mfreq = get_freq_max(*cpu, cpufreq);
		} else { // freq
			int freq;
			ret = sscanf(arg, "%d:%d", cpu, &freq);
			mfreq = get_freq_max(*cpu, cpufreq);
			*ratio = (float)freq / (float)mfreq;
		}
		if (mfreq < 0) {
			printf("Could not get maximum frequency for CPU%d.\n", *cpu);
			goto error;
		}
		if (ret != 2) {
			printf("Unknown CPU specification format: %s.\n", arg);
			goto error;
		}
	}

	for (i=0; i < fields; i++) {
		for (j=i+1; j < fields; j++) {
			if (cmds->ratios[i].cpu == cmds->ratios[j].cpu) {
				printf("Multiple definitions for one CPU.\n");
				goto error;
			}
		}
		if (cmds->ratios[i].ratio < 0.0 || cmds->ratios[i].ratio > 1.0) {
			printf("Incorrect ratio.\n");
			goto error;
		}
	}

	return cmds;
error:
	free(cmds);
	return NULL;
}

