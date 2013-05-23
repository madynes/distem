#include <ruby.h>
#include <signal.h>
#include <unistd.h>
#include <st.h>
#include <sys/wait.h>
#include "main.h"

#define MAX_CPUS 128

static VALUE m_cpu;
static VALUE c_cpuhogs;
cpu_cmds *cmds;

static VALUE cpuhogs_init(VALUE self)
{
	rb_iv_set(self, "@pid", INT2NUM(0));
	cmds = ALLOC(cpu_cmds);
	cmds->cpufreq = 1;
	cmds->interval = 10000000;
	cmds->cpus = 0;

	return self;
}

int parse_hash(VALUE key, VALUE val, VALUE in)
{
	cmds->ratios[cmds->cpus].cpu = NUM2INT(key);
	cmds->ratios[cmds->cpus].ratio = (float) NUM2DBL(val);
	cmds->cpus++;
	return ST_CONTINUE;
}

static VALUE cpuhogs_run(VALUE self, VALUE hash)
{
	int pid;

	pid = fork();
	if (pid < 0)
		rb_raise(rb_eRuntimeError,"fork");
	if (!pid)
	{
		if (setsid() < 0)
			rb_raise(rb_eRuntimeError,"setsid");
		close(STDIN_FILENO);
		close(STDOUT_FILENO);
		close(STDERR_FILENO);

		cmds->ratios = ALLOC_N(cpu_ratio,MAX_CPUS);

		rb_hash_foreach(hash,parse_hash,Qnil);

		run(cmds);
                exit(0);
	}
	else
  {
		rb_iv_set(self, "@pid", INT2NUM(pid));
  }
	return Qnil;
}

static VALUE cpuhogs_stop(VALUE self)
{
	int pid;
	pid = NUM2INT(rb_iv_get(self, "@pid"));
	kill(pid,SIGKILL);
  waitpid(pid,NULL,0);
	rb_iv_set(self, "@pid", INT2NUM(0));

	return Qnil;
}

static VALUE cpuhogs_is_run(VALUE self)
{
	if (NUM2INT(rb_iv_get(self, "@pid")))
		return Qtrue;
	else
		return Qfalse;
}

void Init_cpuhogs()
{
	m_cpu = rb_define_module("CPUExtension");
	c_cpuhogs = rb_define_class_under(m_cpu,"CPUHogs",rb_cObject);
	rb_define_method(c_cpuhogs, "initialize", cpuhogs_init, 0);
	rb_define_attr(c_cpuhogs, "pid", 1, 0);
	rb_define_method(c_cpuhogs, "run", cpuhogs_run, 1);
	rb_define_method(c_cpuhogs, "stop", cpuhogs_stop, 0);
	rb_define_method(c_cpuhogs, "running?", cpuhogs_is_run, 0);
}
