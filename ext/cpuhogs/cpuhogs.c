#include <ruby.h>
#include <signal.h>
#include <unistd.h>
#include "cpuhog.h"

static VALUE m_cpu;
static VALUE c_cpuhogs;

static VALUE cpuhogs_init(VALUE self)
{
	rb_iv_set(self, "@pid", INT2NUM(0));

	return self;
}

static VALUE cpuhogs_run(VALUE self, VALUE arr)
{
	char *argvtmp[128];
	VALUE tmp;
	unsigned int i;
	int pid;

	i = 0;

	argvtmp[i++] = "";

	while ((tmp = rb_ary_pop(arr)) != Qnil)
		argvtmp[i++] = STR2CSTR(tmp);

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

		run(i,argvtmp);
	}
	else
		rb_iv_set(self, "@pid", INT2NUM(pid));

	return Qnil;
}

static VALUE cpuhogs_stop(VALUE self)
{
	int pid;
	pid = NUM2INT(rb_iv_get(self, "@pid"));
	kill(pid,SIGTERM);
	rb_iv_set(self, "@pid", INT2NUM(0));

	return Qnil;
}

void Init_cpuhogs()
{
	m_cpu = rb_define_module("CPUExtension");
	c_cpuhogs = rb_define_class_under(m_cpu,"CPUHogs",rb_cObject);
	rb_define_method(c_cpuhogs, "initialize", cpuhogs_init, 0);
	rb_define_attr(c_cpuhogs, "pid", 1, 0);
	rb_define_method(c_cpuhogs, "run", cpuhogs_run, 1);
	rb_define_method(c_cpuhogs, "stop", cpuhogs_stop, 0);
}
