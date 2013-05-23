#include <ruby.h>
#include <signal.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/wait.h>
#include "cpugov.h"
#include "main.h"

static VALUE m_cpu;
static VALUE c_cpugov;


int cores[MAX_CORES];
unsigned int corenb;
int freq_max;

__inline__ static VALUE cpugov_parse_core(VALUE coreid)
{
  cores[corenb++] = NUM2INT(coreid);

  return Qnil;
}

static VALUE cpugov_init(
  VALUE self,
  VALUE cores,
  VALUE freqmax,
  VALUE cgroup_path
)
{
	rb_iv_set(self, "@pitch", rb_float_new(DEFAULT_PITCH));
	rb_iv_set(self, "@cores", rb_ary_dup(cores));
	rb_iv_set(self, "@freqmax", freqmax);
	rb_iv_set(self, "@pid", INT2NUM(0));
	rb_iv_set(self, "@cgrouppath", rb_str_dup(cgroup_path));

  freq_max = freqmax;

	return self;
}

static VALUE cpugov_run(
  VALUE self,
  VALUE low_freq,
  VALUE high_freq,
  VALUE low_rate
)
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

      rb_iterate(rb_each, rb_iv_get(self,"@cores"), cpugov_parse_core, Qnil);

      extrun(
	     (unsigned long long) (NUM2DBL(rb_iv_get(self, "@pitch")) * 1000000),
	     NUM2INT(low_freq),NUM2INT(high_freq),NUM2DBL(low_rate),
	     STR2CSTR(rb_iv_get(self,"@cgrouppath"))
	     );
      exit(0);
    }
  else
    rb_iv_set(self, "@pid", INT2NUM(pid));

  return Qnil;
}

static VALUE cpugov_stop(VALUE self)
{
	int pid;

	pid = NUM2INT(rb_iv_get(self, "@pid"));
	kill(pid,SIGKILL);
  waitpid(pid,NULL,0);

	rb_iv_set(self, "@pid", INT2NUM(0));

	return Qnil;
}

static VALUE cpugov_is_run(VALUE self)
{
	if (NUM2INT(rb_iv_get(self, "@pid")))
		return Qtrue;
	else
		return Qfalse;
}

void Init_cpugov()
{
	m_cpu = rb_define_module("CPUExtension");
	c_cpugov = rb_define_class_under(m_cpu,"CPUGov",rb_cObject);
	rb_define_method(c_cpugov, "initialize", cpugov_init, 3);
	rb_define_attr(c_cpugov, "pid", 1, 0);
	rb_define_attr(c_cpugov, "pitch", 1, 1);
	rb_define_attr(c_cpugov, "cores", 1, 0);
	rb_define_attr(c_cpugov, "freqmax", 1, 0);
	rb_define_attr(c_cpugov, "cgrouppath", 1, 0);
	rb_define_method(c_cpugov, "run", cpugov_run, 3);
	rb_define_method(c_cpugov, "stop", cpugov_stop, 0);
	rb_define_method(c_cpugov, "running?", cpugov_is_run, 0);
}
