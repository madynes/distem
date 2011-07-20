
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

cpu_cmds* parse_cpus(int argc, char** argv);

