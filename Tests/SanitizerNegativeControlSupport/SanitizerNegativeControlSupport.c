#include "SanitizerNegativeControlSupport.h"

#include <limits.h>

void sanitizer_negative_control_undefined_behavior(void) {
  volatile int maximum = INT_MAX;
  volatile int overflow = maximum + 1;
  (void)overflow;
}
