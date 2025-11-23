#include <Arduino.h>
#include "rtc_controller.h"

void setup()
{
    Serial.begin(115200);
    delay(2000);

    Serial.println("RTC Boost Controller Starting...");

    rtc_init();

    if (!startup_routine())
    {
        Serial.println("Startup failed.");
        while (1) delay(1000);
    }

    Serial.println("Converter running.");
}

void loop()
{
    Serial.println("Heartbeat");
    delay(1000);
}
