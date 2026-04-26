#ifndef RTC_CONTROLLER_H
#define RTC_CONTROLLER_H

#include <Arduino.h>

void rtc_init();

void set_disable(bool on);
void set_manual_on(bool on);

bool startup_routine();
void shutdown_routine();

#endif
