
#define _GNU_SOURCE

#include <pthread.h>
#include <stdlib.h>
#include <sched.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/time.h>
#include <asm/param.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
#include <sys/types.h>
#include <errno.h>
#include "common.h"
#include "main.h"

static double ratio;

static pthread_t* threads;
static pthread_barrier_t barrier;
static lli loops_per_sec;
int finished = 0;
static volatile int ctrlc = 0;
static int return_value = 0;
static int sync_barrier;

static inline lli GET_TIME() {
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return (1000000LL * (lli)tv.tv_sec + (lli)tv.tv_usec);
}

/**
 *	This is a reader-writer lock mechanism (favoring the readers).
 *	Suggested by Thomas Jost.
 *	Taken from http://www710.univ-lyon1.fr/~jciehl/Public/educ/threads.html#attente_passive_posix
 */

static int readers = 0;
static pthread_mutex_t read_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t write_mutex = PTHREAD_MUTEX_INITIALIZER;

static inline void r_lock() {
	pthread_mutex_lock(&read_mutex);
	if (++readers == 1)
		pthread_mutex_lock(&write_mutex);
	pthread_mutex_unlock(&read_mutex);
}

static inline void r_unlock() {
	pthread_mutex_lock(&read_mutex);
	if (--readers == 0)
		pthread_mutex_unlock(&write_mutex);
	pthread_mutex_unlock(&read_mutex);
}

static inline void w_lock() {
	pthread_mutex_lock(&write_mutex);
}

static inline void w_unlock() {
	pthread_mutex_unlock(&write_mutex);
}

static inline void mysleep(long long int ns) {
	struct timespec ts;
	if (clock_gettime(CLOCK_MONOTONIC, &ts)) {
		kill(0, SIGKILL); // kill ourselves
	}
	ts.tv_nsec += ns;
	ts.tv_sec += ts.tv_nsec / 1000000000;
	ts.tv_nsec %= 1000000000;
	
	while (1) {
		int ret = clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &ts, NULL);
		if (ret == -1 && errno == EINTR)
			continue;
		if (!ret)
			break;
		kill(0, SIGKILL);
	}
}

void* thread_fn(void* arg) {
	lli slee, start, end;
	lli loops_ps = loops_per_sec;
	double lratio = 1.0 - ratio;
	double wratio = lratio / (1. - lratio);
	lli loops, i;
	int syncl = sync_barrier;
	int local_finish;
	long long int interval = *((long long int*)arg);
	while(1)
	{
		r_lock();  /* begin reading */
		if (syncl) {
			pthread_barrier_wait(&barrier); // this can't fail according to docs
		}
		local_finish = finished;
		r_unlock();

		if (local_finish) {
			break;
		}

		start = GET_TIME();
		mysleep(interval);
		end = GET_TIME();
		slee = end - start;
		loops = (lli)(loops_ps * slee * wratio / 1000000.0);
		for (i=0; i < loops; i++) {
			LOOP();
		}
	}
	return 0;
}

void handler(int num) {
	/* POSIX mutexes can't be used from signal handlers... */
	ctrlc = 1;
}

static void send_notification() {
	if (write(3, "!", 1) != 1)
		printf("Could not send notification!\n");
	else
		printf("Notification sent.\n");
}

#define ERROR(label)  { return_value = 1; goto label; }

int run(cpu_cmds* cmds) {
	int i;
	struct sched_param param;
	//cpu_cmds* cmds;

	//cmds = parse_cpus(argc, argv);

	if (!cmds) {
		ERROR(finish);
	}

	if (pthread_barrier_init(&barrier, NULL, cmds->cpus)) {
		printf("Could not initialize barrier.\n");
		ERROR(cmds_free);
	}

	if (signal(SIGINT, handler) == SIG_ERR || signal(SIGTERM, handler) == SIG_ERR) {
		printf("Signal handler could not be established.\n");
		ERROR(barrier_free);
	}

	sync_barrier = getInteger("sync", 1);  /* sync by default */

	for (i=1; i < cmds->cpus; i++) {
		if (cmds->ratios[i].ratio != cmds->ratios[0].ratio) {
			printf("All CPUs must have the same ratio.\n");
			ERROR(barrier_free);
		}
	}
	
	ratio = cmds->ratios[0].ratio;

	printf("Syncing: %s\n", (sync_barrier) ? "on" : "off");
	printf("Interval: %lld\n", cmds->interval);
	printf("Cpufreq use: %s\n",cmds->cpufreq ? "yes" : "no");

	for (i=0; i < cmds->cpus; i++) {
		printf("CPU %d ratio = %.3f\n", cmds->ratios[i].cpu, cmds->ratios[i].ratio);
	}

	/* go realtime */
	param.sched_priority = sched_get_priority_max(SCHED_FIFO);
	if (pthread_setschedparam(pthread_self(), SCHED_FIFO, &param)) {
		printf("Bloke! I wanna go pro but I can't! :)\n");
		ERROR(barrier_free);
	}

	/* calibrate */

	loops_per_sec = CALIBRATE(LOOP(), 2.0);
	printf("# loops per second = %lld\n", loops_per_sec);

	threads = (pthread_t*)malloc(sizeof(pthread_t) * cmds->cpus);
	if (!threads) {
		printf("Could not allocate threads.\n");
		ERROR(barrier_free);
	}

	for (i=0; i < cmds->cpus; i++) {
		cpu_set_t cpuset;
		param.sched_priority = sched_get_priority_max(SCHED_FIFO);
		if (pthread_create(&threads[i], NULL, thread_fn, (void*)&cmds->interval)) {
			printf("Could not start thread.\n");
			ERROR(threads_free);
		}
		CPU_ZERO(&cpuset);
		CPU_SET(cmds->ratios[i].cpu, &cpuset);
		if (pthread_setaffinity_np(threads[i], sizeof(cpuset), &cpuset)) {
			printf("Could not set affinity.\n");
			ERROR(threads_free);
		}
		if (pthread_setschedparam(threads[i], SCHED_FIFO, &param)) {
			printf("Could not go realtime.\n");
			ERROR(threads_free);
		}
	}
	
  //send_notification();

	while (1) {
		if (ctrlc) {
			printf("CTRL+C received.\n");
			w_lock(); /* begin writing */
			finished = 1;
			w_unlock(); /* stop writing */
			break;
		}
		usleep(100000);
	}

threads_join:
	
	for (i=0; i < cmds->cpus; i++) {
		if (pthread_join(threads[i], NULL)) {
			printf("Threads could not be joined.\n");
			ERROR(threads_free);
		}
	}

	printf("Threads joined.\n");

threads_free:
	free(threads);
barrier_free:
	pthread_barrier_destroy(&barrier);
cmds_free:
	//free(cmds);
finish:
	printf("return = %d\n", return_value);
	return return_value;
}
