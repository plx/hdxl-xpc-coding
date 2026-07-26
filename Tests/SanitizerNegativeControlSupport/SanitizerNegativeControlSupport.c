#include "SanitizerNegativeControlSupport.h"

#include <limits.h>
#include <pthread.h>
#include <stdatomic.h>

void sanitizer_negative_control_undefined_behavior(void) {
  volatile int maximum = INT_MAX;
  volatile int overflow = maximum + 1;
  (void)overflow;
}

struct sanitizer_negative_control_thread_context {
  atomic_int ready;
  int raced_value;
};

static void *sanitizer_negative_control_thread_worker(void *raw_context) {
  struct sanitizer_negative_control_thread_context *context = raw_context;
  atomic_fetch_add_explicit(&context->ready, 1, memory_order_seq_cst);
  while (atomic_load_explicit(&context->ready, memory_order_seq_cst) < 2) {}
  for (int index = 0; index < 10000; ++index) {
    context->raced_value += 1;
  }
  return NULL;
}

void sanitizer_negative_control_thread(void) {
  struct sanitizer_negative_control_thread_context context = {
    .ready = 0,
    .raced_value = 0,
  };
  pthread_t first_thread;
  pthread_t second_thread;
  pthread_create(
    &first_thread,
    NULL,
    sanitizer_negative_control_thread_worker,
    &context
  );
  pthread_create(
    &second_thread,
    NULL,
    sanitizer_negative_control_thread_worker,
    &context
  );
  pthread_join(first_thread, NULL);
  pthread_join(second_thread, NULL);
}
