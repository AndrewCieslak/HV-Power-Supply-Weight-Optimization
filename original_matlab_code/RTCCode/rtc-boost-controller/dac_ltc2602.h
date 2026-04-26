#ifndef DAC_LTC2602_H
#define DAC_LTC2602_H

#include <Arduino.h>
#include <SPI.h>

#define DAC_CHANNEL_A 0
#define DAC_CHANNEL_B 1

// Arduino pin mapping for XIAO-nRF52840
#define DAC_CS_PIN   10   // P1.12

// Vref (volts) used to convert volts -> DAC code
#ifndef LTC2602_VREF_V
#define LTC2602_VREF_V 3.3f
#endif

void dac_init();
bool dac_write_u16(uint8_t channel, uint16_t code);

bool set_zvs_limit_voltage(float volts);  // DAC channel A
bool set_ctrl_voltage(float volts);       // DAC channel B

#endif
