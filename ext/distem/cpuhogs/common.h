
#include <sys/time.h>
#include <sys/resource.h>
#include <time.h>

#ifndef LORIA
#define LORIA 1

#include <stdlib.h>

typedef long long int lli;

typedef struct {
	struct timeval cpu;
	struct timeval wall;
} timestamp;

typedef struct {
	double cpu;
	double wall;
	lli loops;
} timespan;

static inline timestamp get_time() {
	timestamp ts;
	struct rusage u;
	
	getrusage(RUSAGE_SELF, &u);
	ts.cpu = u.ru_utime;
	gettimeofday(&ts.wall, NULL);
	
	return ts;
}

static inline double sub_time(struct timeval t1, struct timeval t2) {
	long long int s  = t1.tv_sec - t2.tv_sec;
	long long int u  = t1.tv_usec - t2.tv_usec;
	return (double)(s) + ((double)(u)) * 1e-6;
}

static inline timespan get_diff(timestamp end, timestamp start) {
	timespan ts;
	ts.cpu = sub_time(end.cpu, start.cpu);
	ts.wall = sub_time(end.wall, start.wall);
	return ts;
}

extern int LOOP2(int);

static unsigned long long LOOP() {
	return LOOP2(0);
}

#define LOOPS(loops) do { int _i; for (_i=0; _i < (loops); _i++) LOOP(); } while (0);

static double __cpu, __wall;
static lli __loops;

#define CALIBRATE(CODE, T) ({ \
		printf("# calibrating for %.2lf seconds.\n", (T)); \
		timestamp __a, __b; timespan __c; lli __i; \
		__loops = 1; __wall = 0; \
		while (1) { \
			__a = get_time(); for(__i=0; __i < __loops; __i++) do { CODE; } while(0); __b = get_time(); \
			__c = get_diff(__b, __a); __cpu = __c.cpu; __wall = __c.wall; \
			printf("# %lld loop%s took %.8lf s\n", __loops, (__loops == 1) ? "" : "s", __wall); \
			if (__wall > 0.1) break; \
			__loops <<= 1; \
		} \
		__loops = (long long int)((T) * __loops / __wall) + 1; \
		__loops; \
   });

#define MEASURE(CODE, T) ({ \
			lli __i; timestamp __a, __b; timespan __c; \
			CALIBRATE(CODE, T); \
			printf("# performing loop %lld times\n", __loops); \
			__a = get_time(); \
			for(__i=0; __i < __loops; __i++) do { CODE; } while (0); \
			__b = get_time(); \
			__c = get_diff(__b, __a); __c.loops = __loops; \
			__c; \
	});

#define GET_CAST(name,func) \
	({ char* _s; ((_s = getenv(name)) != NULL) ? func(_s) : def; })
	
int getInteger(char* name, int def) {
	return GET_CAST(name, atoi);
}

static double todouble(char* s) {
	return strtod(s, NULL);
}

double getDouble(char* name, double def) {
	return GET_CAST(name, todouble);
}

double TIME(double def) {
	return getDouble("time", def);
}

double process_time() {
	struct timespec ts;
	clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts);
	return (double)ts.tv_sec + (double)ts.tv_nsec / 1000000000.0;
}

double thread_time() {
	struct timespec ts;
	clock_gettime(CLOCK_THREAD_CPUTIME_ID, &ts);
	return (double)ts.tv_sec + (double)ts.tv_nsec / 1000000000.0;
}

#endif
