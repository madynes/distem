#include <sys/types.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <sys/resource.h>
#include <unistd.h>
#include <getopt.h>
#include "cpubench.h"


/* Function's source: http://www.gnu.org/s/hello/manual/libc/Elapsed-Time.html */
int timeval_subtract (result, x, y)
	struct timeval *result, *x, *y;
{
	/* Perform the carry for the later subtraction by updating y. */
	if (x->tv_usec < y->tv_usec) {
		int nsec = (y->tv_usec - x->tv_usec) / 1000000 + 1;
		y->tv_usec -= 1000000 * nsec;
		y->tv_sec += nsec;
	}
	if (x->tv_usec - y->tv_usec > 1000000) {
		int nsec = (x->tv_usec - y->tv_usec) / 1000000;
		y->tv_usec += 1000000 * nsec;
		y->tv_sec -= nsec;
	}

	/* Compute the time remaining to wait.
	   tv_usec is certainly positive. */
	result->tv_sec = x->tv_sec - y->tv_sec;
	result->tv_usec = x->tv_usec - y->tv_usec;

	/* Return 1 if result is negative. */
	return x->tv_sec < y->tv_sec;
}

__inline__ void
loop()
{
        register int i, j, x;

	x = LOOP_SEED;
        for (i=0; i < 1000; i++)
                for (j=0; j < 100; j++)
                        x ^= x + (i & j);
}

__inline__ void
loops(unsigned int times)
{
	while (times--)
		loop();
}

__inline__ unsigned long long int
calibrate()
{
	struct timeval time_start, time_end, time_diff;
	double walltime;
	unsigned long long int loopnb, prevloopnb;
	unsigned int reloop,chdirnb, samedirnb, pitch;
	char dir;

	walltime = 0.0f;
	loopnb = 1;
	while (walltime < CALIB_THRESHOLD)
	{
		gettimeofday(&time_start, NULL);
		loops(loopnb);
		gettimeofday(&time_end, NULL);
		timeval_subtract(&time_diff,&time_end,&time_start);
		walltime = TIMEVAL2DOUBLE(time_diff);
		loopnb <<= 1;
	}

	prevloopnb = 0;
	chdirnb = 0;
	samedirnb = 0;
	reloop = 0;
	dir = 0;
	pitch = (loopnb - (loopnb>>1))/8;

	while (
	(reloop < CALIB_MAX_RELOOP)
	&& ((loopnb-prevloopnb) > 1)
	&& ((prevloopnb-loopnb) > 1)
	&& ((loopnb != prevloopnb)
	|| (walltime > (CALIB_THRESHOLD + (CALIB_THRESHOLD/10)))
	|| (walltime < (CALIB_THRESHOLD - (CALIB_THRESHOLD/10))))
	)
	{
		gettimeofday(&time_start, NULL);
		loops(loopnb);
		gettimeofday(&time_end, NULL);
		timeval_subtract(&time_diff,&time_end,&time_start);
		walltime = TIMEVAL2DOUBLE(time_diff);
		prevloopnb = loopnb;
		if (walltime > CALIB_THRESHOLD)
		{
			loopnb -= pitch;

			if (dir > 0)
				chdirnb++;
			else
				samedirnb++;
			dir = -1;
		}
		else
		{
			loopnb += pitch;

			if (dir < 0)
				chdirnb++;
			else
				samedirnb++;
			dir = 1;
		}

		if (chdirnb > CALIB_MAX_CHDIR)
		{
			pitch /= 2;
			chdirnb = 0;
		}

		if (samedirnb > CALIB_MAX_SAMEDIR)
		{
			pitch *= 2;
			samedirnb = 0;
		}

		reloop++;
	}

	DEBUG("calibloop: %lld\ncalibwall:%lf\n",loopnb,walltime);

	return (unsigned long long int) (loopnb / walltime);
}

double bench(unsigned int procnb, unsigned long long loopbase)
{
	int status, pids[MAX_PROCNB];
	double walltime;
	unsigned int tmp;
	struct timeval time_start, time_end, time_diff;

	if (procnb > 1)
	{
		tmp = procnb;
		gettimeofday(&time_start,NULL);
		while (tmp--)
		{
			if (!(pids[tmp] = fork()))
			{
				loops(loopbase);
				exit(0);
			}
		}
		while (procnb--)
			waitpid(pids[procnb],&status,0);
		
		gettimeofday(&time_end,NULL);
	}
	else
	{
		gettimeofday(&time_start,NULL);
		loops(loopbase);
		gettimeofday(&time_end,NULL);
	}

	timeval_subtract(&time_diff,&time_end,&time_start);
	walltime = TIMEVAL2DOUBLE(time_diff);

	DEBUG("walltime: %.5f\nresult:%lf\n",walltime,(loopbase / walltime));

	return (loopbase / walltime);
}

int main(int argc, char **argv)
{
	int tmp;
	unsigned int procnb, repeat;
	unsigned long long int loopbase;
	double result;
	float time_base;

	time_base = DEFAULT_TIME;
	procnb = DEFAULT_PROCNB;
	repeat = DEFAULT_REPEAT;

	while ((tmp = getopt (argc, argv, "dn:p:t:")) != -1)
	{
		switch(tmp)
		{
		case 'd':
			options |= OPT_DEBUG;
			break;
		case 'p':
			procnb = strtol(optarg,0,10);
			break;
		case 'n':
			repeat = strtol(optarg,0,10);
			break;
		case 't':
			time_base = strtof(optarg,0);
			break;
		case '?':
			if ((optopt == 'c') || (optopt == 'p') || (optopt == 'n'))
				fprintf (stderr, "Option -%c requires an argument.\n", optopt);
			else
				fprintf (stderr, "Unknown option '-%c'.\n", optopt);
		default:
			abort();
		}
	}

	DEBUG("procs: %d\n",procnb);


	loopbase = calibrate();
	loopbase = (__typeof__(loopbase)) (loopbase * time_base);
	DEBUG("loopbase: %lld\ntimebase: %.2f\n",loopbase,time_base);

	tmp = repeat;
	result = 0.0;
	while (tmp--)
	{
		DEBUG("Repeat #%d\n",(repeat-tmp));
		result += (bench(procnb,loopbase) / repeat);
	}

	fprintf(stdout,"%lf\n", result);

	return 0;
}
