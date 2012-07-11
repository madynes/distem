#include "ruby.h"
#include "RngStream.h"

void Init_rngstream();

VALUE rng_initialize(VALUE self);

VALUE rng_set_seed(VALUE self, VALUE seed);

VALUE rng_get_rand(VALUE self);

VALUE rng_advance_state(VALUE self, VALUE dispacement);

void rng_free(void* ptr);
