#include "ruby.h"
#include "ruby/thread.h"
#include "rubyspec.h"

#include <math.h>
#include <errno.h>
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#if defined(_WIN32)
#include "ruby/win32.h"
#define read rb_w32_read
#define write rb_w32_write
#define pipe rb_w32_pipe
#endif

#ifndef _WIN32
#include <pthread.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

static VALUE thread_spec_rb_thread_alone(VALUE self) {
  return rb_thread_alone() ? Qtrue : Qfalse;
}

/* This is unblocked by unblock_func(). */
static void* blocking_gvl_func(void* data) {
  int rfd = *(int *)data;
  char dummy = ' ';
  ssize_t r;

  do {
    r = read(rfd, &dummy, 1);
  } while (r == -1 && errno == EINTR);

  close(rfd);

  return (void*)((r == 1 && dummy == 'A') ? Qtrue : Qfalse);
}

static void unblock_gvl_func(void *data) {
  int wfd = *(int *)data;
  char dummy = 'A';
  ssize_t r;

  do {
    r = write(wfd, &dummy, 1);
  } while (r == -1 && errno == EINTR);

  close(wfd);
}

/* Returns true if the thread is interrupted. */
static VALUE thread_spec_rb_thread_call_without_gvl(VALUE self) {
  int fds[2];
  void* ret;

  if (pipe(fds) == -1) {
    rb_raise(rb_eRuntimeError, "could not create pipe");
  }
  ret = rb_thread_call_without_gvl(blocking_gvl_func, &fds[0],
                                   unblock_gvl_func, &fds[1]);
  return (VALUE)ret;
}

/* This is unblocked by a signal. */
static void* blocking_gvl_func_for_ubf_io(void *data) {
  int rfd = (int)(size_t)data;
  char dummy;

  if (read(rfd, &dummy, 1) == -1 && errno == EINTR) {
    return (void*)Qtrue;
  } else {
    return (void*)Qfalse;
  }
}

/* Returns true if the thread is interrupted. */
static VALUE thread_spec_rb_thread_call_without_gvl_with_ubf_io(VALUE self) {
  int fds[2];
  void* ret;

  if (pipe(fds) == -1) {
    rb_raise(rb_eRuntimeError, "could not create pipe");
  }

  ret = rb_thread_call_without_gvl(blocking_gvl_func_for_ubf_io,
                                  (void*)(size_t)fds[0], RUBY_UBF_IO, 0);
  close(fds[0]);
  close(fds[1]);
  return (VALUE)ret;
}

static VALUE thread_spec_rb_thread_current(VALUE self) {
  return rb_thread_current();
}

static VALUE thread_spec_rb_thread_local_aref(VALUE self, VALUE thr, VALUE sym) {
  return rb_thread_local_aref(thr, SYM2ID(sym));
}

static VALUE thread_spec_rb_thread_local_aset(VALUE self, VALUE thr, VALUE sym, VALUE value) {
  return rb_thread_local_aset(thr, SYM2ID(sym), value);
}

static VALUE thread_spec_rb_thread_wakeup(VALUE self, VALUE thr) {
  return rb_thread_wakeup(thr);
}

static VALUE thread_spec_rb_thread_wait_for(VALUE self, VALUE s, VALUE ms) {
  struct timeval tv;
  tv.tv_sec = NUM2INT(s);
  tv.tv_usec = NUM2INT(ms);
  rb_thread_wait_for(tv);
  return Qnil;
}

VALUE thread_spec_call_proc(void *arg_ptr) {
  VALUE arg_array = (VALUE)arg_ptr;
  VALUE arg = rb_ary_pop(arg_array);
  VALUE proc = rb_ary_pop(arg_array);
  return rb_funcall(proc, rb_intern("call"), 1, arg);
}

static VALUE thread_spec_rb_thread_create(VALUE self, VALUE proc, VALUE arg) {
  VALUE args = rb_ary_new();
  rb_ary_push(args, proc);
  rb_ary_push(args, arg);

  return rb_thread_create(thread_spec_call_proc, (void*)args);
}

static VALUE thread_spec_ruby_native_thread_p(VALUE self) {
  if (ruby_native_thread_p()) {
    return Qtrue;
  } else {
    return Qfalse;
  }
}

#ifndef _WIN32
static VALUE false_result = Qfalse;
static VALUE true_result = Qtrue;

static void *new_thread_check(void *args) {
  if (ruby_native_thread_p()) {
    return &true_result;
  } else {
    return &false_result;
  }
}
#endif

static VALUE thread_spec_ruby_native_thread_p_new_thread(VALUE self) {
#ifndef _WIN32
    pthread_t t;
    void *result = &true_result;
    pthread_create(&t, NULL, new_thread_check, NULL);
    pthread_join(t, &result);
    return *(VALUE *)result;
#else
    return Qfalse;
#endif
}

#ifdef RUBY_VERSION_IS_3_5
static VALUE thread_spec_ruby_thread_has_gvl_p(VALUE self) {
  return ruby_thread_has_gvl_p() ? Qtrue : Qfalse;
}
#endif

void Init_thread_spec(void) {
  VALUE cls = rb_define_class("CApiThreadSpecs", rb_cObject);
  rb_define_method(cls, "rb_thread_alone", thread_spec_rb_thread_alone, 0);
  rb_define_method(cls, "rb_thread_call_without_gvl", thread_spec_rb_thread_call_without_gvl, 0);
  rb_define_method(cls, "rb_thread_call_without_gvl_with_ubf_io", thread_spec_rb_thread_call_without_gvl_with_ubf_io, 0);
  rb_define_method(cls, "rb_thread_current", thread_spec_rb_thread_current, 0);
  rb_define_method(cls, "rb_thread_local_aref", thread_spec_rb_thread_local_aref, 2);
  rb_define_method(cls, "rb_thread_local_aset", thread_spec_rb_thread_local_aset, 3);
  rb_define_method(cls,  "rb_thread_wakeup", thread_spec_rb_thread_wakeup, 1);
  rb_define_method(cls,  "rb_thread_wait_for", thread_spec_rb_thread_wait_for, 2);
  rb_define_method(cls,  "rb_thread_create", thread_spec_rb_thread_create, 2);
  rb_define_method(cls,  "ruby_native_thread_p", thread_spec_ruby_native_thread_p, 0);
  rb_define_method(cls,  "ruby_native_thread_p_new_thread", thread_spec_ruby_native_thread_p_new_thread, 0);
#ifdef RUBY_VERSION_IS_3_5
  rb_define_method(cls,  "ruby_thread_has_gvl_p", thread_spec_ruby_thread_has_gvl_p, 0);
#endif
}

#ifdef __cplusplus
}
#endif
