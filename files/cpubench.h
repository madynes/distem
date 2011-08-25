#ifndef _CPUBENCH_H
#define _CPUBENCH_H

#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>

char options = 0;

#define CALIB_THRESHOLD 0.1f
#define CALIB_MAX_RELOOP 64
#define CALIB_MAX_CHDIR 3
#define CALIB_MAX_SAMEDIR 3

#define LOOP_SEED ~0

#define DEFAULT_TIME 2.0f
#define DEFAULT_PROCNB 2
#define DEFAULT_REPEAT 3

#define MAX_PROCNB 128

#define TIMEVAL2DOUBLE(T) (((double) (T).tv_sec) + (((double) (T).tv_usec) * 1e-6))

enum options_val
{
	OPT_DEBUG = 1
};

#define DEBUG(format,...) \
do { \
	if (options & OPT_DEBUG) \
		fprintf(stdout,format,##__VA_ARGS__); \
} while(0);

int timeval_subtract (struct timeval *result, struct timeval *x, struct timeval *y);
void loop();
void loops(unsigned int times);
unsigned long long int calibrate();

#endif
