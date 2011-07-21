#include <ruby.h>
#include "cpuhog.h"

static VALUE m_cpu;
static VALUE c_cpuhogs;

static VALUE cpuhogs_initialize(VALUE self)
{
}

static VALUE cpuhogs_run(VALUE self, VALUE arr)
{
	char *argvtmp[128];
	VALUE tmp;
	unsigned int i;

	i = 0;

	argvtmp[i++] = "";

	while ((tmp = rb_ary_pop(arr)) != Qnil)
		argvtmp[i++] = STR2CSTR(tmp);

	run(i,argvtmp);
}

void Init_cpuhogs_ext()
{
	m_cpu = rb_define_module("CPUExtension");
	c_cpuhogs = rb_define_class_under(m_cpu,"CPUHogs",rb_cObject);
	rb_define_method(c_cpuhogs, "initialize", cpuhogs_initialize, 0);
	rb_define_method(c_cpuhogs, "run", cpuhogs_run, 1);
}
