# RTC Boost Controller (Arduino version)

This is the Arduino-compatible firmware for controlling an RTC-style
resonant transition boost converter using:

- Seeed XIAO-nRF52840
- LTC2602 (dual 16-bit DAC)

## Pin Connections

| Function | XIAO Pin |
|---------|----------|
| MOSI    | 11       |
| SCK     | 13       |
| CS      | 10       |
| Disable | 3        |
| ManualOn| 2        |

## Required Libraries

- **SPI** (built-in)

## Building

Open `rtc_boost_controller.ino` in Arduino IDE.
Select:
