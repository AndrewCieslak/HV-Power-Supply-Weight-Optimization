#include "dac_ltc2602.h"

// SPI settings for LTC2602: mode 0, MSB first, up to 50 MHz (we use 4 MHz)
static SPISettings dacSPISettings(4000000, MSBFIRST, SPI_MODE0);

void dac_init()
{
    pinMode(DAC_CS_PIN, OUTPUT);
    digitalWrite(DAC_CS_PIN, HIGH); // CS idle high

    SPI.begin(); // initializes SCK=13, MOSI=11
}

bool dac_write_u16(uint8_t channel, uint16_t code)
{
    if (channel > 1) return false;

    uint8_t cmd = (0x3 << 4) | (channel & 0x0F); // Write+Update command

    SPI.beginTransaction(dacSPISettings);
    digitalWrite(DAC_CS_PIN, LOW);

    SPI.transfer(cmd);
    SPI.transfer((code >> 8) & 0xFF);
    SPI.transfer(code & 0xFF);

    digitalWrite(DAC_CS_PIN, HIGH);
    SPI.endTransaction();

    delayMicroseconds(2); // settling margin

    return true;
}

static uint16_t volts_to_code(float v)
{
    if (v <= 0) return 0;
    if (v >= LTC2602_VREF_V) return 0xFFFF;

    float scaled = (v / LTC2602_VREF_V) * 65535.0f;
    return (uint16_t)(scaled + 0.5f);
}

bool set_zvs_limit_voltage(float volts)
{
    return dac_write_u16(DAC_CHANNEL_A, volts_to_code(volts));
}

bool set_ctrl_voltage(float volts)
{
    return dac_write_u16(DAC_CHANNEL_B, volts_to_code(volts));
}
