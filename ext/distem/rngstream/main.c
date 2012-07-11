#include "main.h"

/*
 * This program interfaces RngStream C functions and Ruby, so RngStream
 * functions can be used in Ruby programs like Distem.
 */

VALUE m_random = Qnil;
VALUE c_rngstream = Qnil;

void Init_rngstream() {
  m_random = rb_define_module("RandomExtension");
  c_rngstream = rb_define_class_under(m_random, "RngStream", rb_cObject);
  rb_define_method(c_rngstream, "initialize", rng_initialize, 0);
  rb_define_method(c_rngstream, "set_seed", rng_set_seed, 1);
  rb_define_method(c_rngstream, "randU01", rng_get_rand, 0);
  rb_define_method(c_rngstream, "advance_state", rng_advance_state, 1);
  rb_define_attr(c_rngstream, "stream_prt", 0, 0);
}

VALUE rng_initialize(VALUE self) {
  RngStream stream = RngStream_CreateStream(NULL);
  VALUE stream_ptr = Data_Wrap_Struct(rb_cObject, 0, rng_free, (void*) stream);
  rb_iv_set(self, "@stream_prt", stream_ptr);
  return self;
}

void rng_free(void* ptr) {
  RngStream stream = (RngStream) ptr;
  RngStream_DeleteStream(&stream);
}

// seed MUST be an array of at least 6 numbers, or you will get a segfault !
VALUE rng_set_seed(VALUE self, VALUE seed) {
  unsigned long seed_arr[6];
  int i;
  
  for(i=0 ; i<6 ; i++) {
    seed_arr[i] = NUM2ULONG(rb_ary_entry(seed, i));
  }
  VALUE stream_ptr = rb_iv_get(self, "@stream_prt");
  RngStream stream;
  Data_Get_Struct(stream_ptr, RngStream, stream);

  int error = RngStream_SetSeed(stream, seed_arr);
  if(error) {
    rb_raise(rb_eArgError, "Invalid seed");
  }
  RngStream_ResetStartStream(stream);
  return self;
}

VALUE rng_get_rand(VALUE self) {
  VALUE stream_ptr = rb_iv_get(self, "@stream_prt");
  RngStream stream;
  Data_Get_Struct(stream_ptr, RngStream, stream);
  double rand_value = RngStream_RandU01(stream);
  return rb_float_new(rand_value);
}

VALUE rng_advance_state(VALUE self, VALUE dispacement) {
  VALUE stream_ptr = rb_iv_get(self, "@stream_prt");
  RngStream stream;
  Data_Get_Struct(stream_ptr, RngStream, stream);
  RngStream_AdvanceState(stream, 0, FIX2LONG(dispacement));
  return self;
}
