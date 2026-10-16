# Measurements

This guide explains what each channel can measure and how MooshRevolt sets up
the meter. To configure a channel, tap its range chip or the tune icon on its
reading card.

## Jacks and channels

The Mooshimeter has four jacks, laid out as a diamond on the case:

```
        V          V  voltage input, up to 600 V   → always CH2
    A       Ω      A  current input, up to 10 A    → always CH1
        C          Ω  aux input: low voltage, resistance, diode → CH1 or CH2
                   C  common: the black probe, for every measurement
```

The red probe goes into the jack of what you measure; the black probe always
goes into C. To measure a battery, put the red probe in **V** and read
**CH2**. The aux input (Ω) also measures voltage, but only up to 1.2 V and
not through the V jack, so a battery on V does not show there.

The **Meter guide** (the **?** button in the toolbar, or "How do I connect?"
in a channel's settings) shows the jacks with the ranges your meter reports,
step-by-step recipes for voltage, current, resistance, diodes, power and a
thermocouple, safety notes, and links to the official cheat sheet and
manual. Each recipe's **Set up the meter** button configures the channels
for it.

Each reading card names its measurement first, then its channel and jack
("Voltage DC · CH2 · V jack + C"), with a small jack diagram. The channel
configuration opens with **Connect your probes**, which lights the jacks to
use. If you pick Voltage on CH1 or Current on CH2, the app sets it up on the
channel wired to that jack and switches there.

## Inputs and modes

The Mooshimeter has two channels. Each channel has a dedicated input and can
also use the shared aux input.

| Mode | CH1 | CH2 | Unit | Ranges |
| --- | --- | --- | --- | --- |
| Current DC / AC | ✓ (A–C) | | A | 10 A |
| Voltage DC / AC | | ✓ (V–C) | V | 60 V, 600 V |
| Internal Temperature | ✓ | ✓ | °C | — (no probes) |
| Auxiliary Voltage DC / AC | ✓ (Ω–C) | ✓ (Ω–C) | V | 100 mV, 300 mV, 1.2 V |
| Resistance | ✓ (Ω–C) | ✓ (Ω–C) | Ω | 1 kΩ, 10 kΩ, 100 kΩ, 1 MΩ, 10 MΩ |
| Diode Drop | ✓ (Ω–C) | ✓ (Ω–C) | V | 1.2 V |

Auxiliary voltage, resistance and diode drop use the shared input, so only one
channel can use them at a time. The configuration sheet disables these modes
on one channel while the other channel uses the shared input.

MooshRevolt reads the available options and ranges from the meter's
configuration tree when it connects. It then selects each option by name, so
every mode configures the hardware that it names.

## Ranges and auto-ranging

Each card shows the active range, for example **Auto · 60 V**. Auto-ranging
works like a bench meter:

1. It starts on the highest range.
2. When a reading goes above 110% of the range, it moves up one range.
3. When a reading uses less than 90% of a smaller range, it moves straight
   down to that range.

Select a fixed range in the configuration sheet to stop auto-ranging, for
example before you log to the SD card.

## Overload

When a reading is above 120% of the active range, the input is saturated and
the value is not a measurement. The display then shows **OL**. The chart
leaves a gap, and CSV exports write `OL`.

A resistance far below zero also shows **OL**. This occurs when an external
voltage drives the probes. Do not measure resistance on a powered circuit.

## Digits and units

The decimal point and the prefix are set by the range, so the digits do not
move while the value changes. The number of digits follows the resolution of
the analog-to-digital converter (ADC) at the current sample rate. At 125 Hz
the meter resolves about 6 digits. At 8 kHz it resolves about 4.

The units menu on each card selects a fixed prefix, for example mA or kΩ.
**Auto** follows the range.

Internal temperature is reported by the meter in kelvin. MooshRevolt shows it
in degrees Celsius.

## Sample rate

**Auto** is the default. It uses these settings:

- 125 Hz with 64-sample averaging for DC measurements, for the most digits.
- 4 kHz with 256-sample averaging when a channel measures AC (RMS), so each
  reading covers several complete mains cycles.

You can select a fixed rate from the menu or in Meter settings.

## Math channel

**Math** in the menu adds a third reading derived from both channels:

| Function | Needs | Result |
| --- | --- | --- |
| Real power | CH1 current, CH2 voltage (both DC or both AC) | W, computed by the meter from the sample buffers |
| Apparent power | the same | VA, CH1 × CH2 |
| Power factor | the same | real power ÷ apparent power |
| Thermocouple (type K) | one channel on Aux voltage DC with the thermocouple, the other on Temperature | the meter's temperature plus the thermocouple's difference |

When the channels do not match, the card explains what it needs and offers
**Set up channels**. The thermocouple uses the ITS-90 type-K polynomial,
valid from 0 to 500 °C above the meter's own temperature. Like the original
Mooshimeter app, it treats the meter's internal temperature as the cold
junction, so keep the thermocouple's connection near the meter.

## Waveform view

**Show waveform** in the menu turns the chart into a simple oscilloscope. The
meter then streams each channel's raw sample buffer instead of its averaged
value, and the chart shows the latest buffer against time in milliseconds:
64 samples over 512 ms at 125 Hz, or 256 samples over 64 ms at 4 kHz, which
covers about three mains cycles.

The readings, tones, recording and exporter keep working: each value is the
mean (DC) or RMS (AC) of its buffer. The meter sends buffer samples with
fewer bits than its averaged values (8 bits at 125 Hz on a V.1), so readings
are coarser in this view. Select **Show reading history** to return.

## Recording

Select the red **Record** button in the toolbar to write every reading the
meter sends to a CSV file in `Downloads/MooshRevolt`. Recording has no time
limit and keeps going across reconnects; the footer shows the elapsed time
and the row count. Select the button again to stop.

Each row holds a timestamp and, for each channel, its mode, value and unit,
for example `current,2.5,A,voltage,14.2,V`. Rows stay correct when you
change a mode during a recording. Overloaded readings are written as `OL`.
**Save chart data (CSV)** in the menu exports only what the chart shows.

## Zero (relative reading)

**Zero** stores the present reading as an offset, and the meter subtracts it
from later readings. In resistance mode, short the probes and zero to remove
the lead resistance. Select **Clear** to remove the offset. The offset is
stored in the meter.

## Continuity

In resistance mode, the configuration sheet has two options:

- **Continuity tone** plays a continuous tone while the resistance is below
  50 Ω. Shorted probes often read slightly below zero, for example −1 Ω,
  because of the zero offset, so the test uses the magnitude of the
  resistance. While the tone is on, the 1 kΩ range is held, so the tone does
  not wait for auto-ranging.
- **Continuity graph** plots the channel as open or continuous instead of
  ohms.

## Diode drop

Diode drop measures the forward voltage of a diode. The meter sends a small,
constant test current through the part and shows the voltage across it.

| Part | Typical forward voltage |
| --- | --- |
| Silicon diode | 0.6–0.7 V |
| Schottky diode | 0.2–0.4 V |
| LED | 1.8–3 V (may light faintly) |

In diode mode, the configuration has a **Short tone** that beeps below
0.1 V, which means the diode is shorted.

A diode conducts in one direction only. If the reading shows **OL**, reverse
the probes. A good diode shows a forward voltage in one direction and **OL**
in the other. An open diode shows **OL** in both directions, because the
open-circuit voltage is more than the 1.2 V range. A shorted diode reads near
0 V in both directions.
