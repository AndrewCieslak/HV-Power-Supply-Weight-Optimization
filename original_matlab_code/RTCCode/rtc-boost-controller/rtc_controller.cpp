#include "rtc_controller.h"
#include "dac_ltc2602.h"

// Arduino pins for XIAO
#define PIN_DISABLE   3   // P0.29
#define PIN_MANUALON  2   // P0.28

#define MANUAL_ON_PULSE_MS 100
#define MANUAL_ON_RETRY_MS 200
#define STARTUP_MAX_MS     2000

void rtc_init()
{
    dac_init();

    pinMode(PIN_DISABLE, OUTPUT);
    pinMode(PIN_MANUALON, OUTPUT);

    set_disable(true);
    set_manual_on(false);

    set_zvs_limit_voltage(0.0f);
    set_ctrl_voltage(0.0f);
}

void set_disable(bool on)
{
    digitalWrite(PIN_DISABLE, on ? HIGH : LOW);
}

void set_manual_on(bool on)
{
    digitalWrite(PIN_MANUALON, on ? HIGH : LOW);
}

bool startup_routine()
{
    uint32_t elapsed = 0;

    set_disable(true);
    set_manual_on(false);

    // conservative initial thresholds
    set_zvs_limit_voltage(0.05f);
    set_ctrl_voltage(0.05f);

    delay(20);

    while (elapsed < STARTUP_MAX_MS)
    {
        set_manual_on(true);
        delay(MANUAL_ON_PULSE_MS);
        set_manual_on(false);
        delay(MANUAL_ON_RETRY_MS);

        elapsed += MANUAL_ON_PULSE_MS + MANUAL_ON_RETRY_MS;
    }

    set_disable(false);

    // nominal running values – adjust after hardware testing
    set_zvs_limit_voltage(0.8f);
    set_ctrl_voltage(1.2f);

    return true;
}

void shutdown_routine()
{
    set_disable(true);
    set_manual_on(false);

    set_zvs_limit_voltage(0.0f);
    set_ctrl_voltage(0.0f);
}
